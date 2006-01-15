=head1 NAME

Config::Generic - Sophisticated Config Parsing Module

=head1 SYNOPSIS

 use Config::Generic;

 # load $grammar from somewhere

 $parser = new Config::Generic($grammar);

 # load $text with user configuration

 my $config = $parser->parse($text);

 # Use tied hash interface
 my $chash;
 tie $chash, "Config::Generic::TieWrapper", {
     Config => $config,
     HashNamedSections => 1,
     TiedDirectives => 0 };

 # Read an option
 if($config->{CreateBackups} eq "true") {
     ...

 # Access a section
 my $block = $config->{Colors};
 print $block->{Titlebar};
 print $block->{Background};

=head1 ABSTRACT

This module parses and verifies configuration files for you. The
format of config files supported by B<Config::Generic> is inspired
by the well known apache config format. Additional features are
advanced syntactic verification using a specfile, here-documents
and flexible access methods.

=head1 DESCRIPTION

The B<new> method requires one parameter that must contain a
grammar specification to verify the configuration. The B<parse> method
parses the given text and ensures the syntax described by the
grammarfile. The B<parse> method returns a configuration object
of type B<Config::Generic::UnnamedSection>. This object can be
used to access the configuration. (see L<Config::Generic::Section> for
details).

Using B<Config::Generic::TieWrapper> you can tie an hash to the
configuration. You can than access the configuration is if it were
stored in an anonymous hash/array structure instead of the object
orientated interface.

The format of config files supported by B<Config::Generic> is inspired
by the well known apache config format, in fact, this module is 100%
compatible to apache configs, but you can also just use simple
name/value pairs in your config files.

In addition to the capabilities of an apache config file it supports
some enhancements such as here-documents and syntactic verification
based on templates.

=head1 METHODS

=over

=cut

package Config::Generic;

use strict;
use warnings;
use Carp;
use constant true => 1;
use constant false => 0;

use Config::Generic::Parser;
use Config::Generic::TieWrapper;

use Data::Dumper;

our $VERSION = '0.01';

=item new(B<$grammar>)

This method returns a B<Config::Generic> object, initialized to
parse a configuration file conforming to B<$grammar>.

=cut
sub new
{
    my $class = shift;
    my $grammar = shift;
    my($parser, $this);

    $class = ref $class || $class;

    # Create generic parser
    $this->{parser} = new Config::Generic::Parser();

    bless $this, $class;

    # Load config specification
    eval {
        my $metaspec;
        tie(%$metaspec, "Config::Generic::TieWrapper",
            { Config => $this->{parser}->startrule(join("", <DATA>)),
              HashNamedSections => true,
              TieDirectives => "no" });
        $this->{spec} = $metaspec;

        my $spec = $this->{parser}->startrule($grammar);
        $this->verify($spec, $metaspec);
        $this->verify_spec($spec, $spec);

        # Use the tied hash interface to access the spec
        my $tiedspec = {};
        tie(%$tiedspec, "Config::Generic::TieWrapper",
            { Config => $spec,
              HashNamedSections => true,
              TieDirectives => "no" });
        $this->{spec} = $tiedspec;
    }; if($@) {
        croak("Invalid grammar specification:\n", $@);
    }

    return $this;
}

=item parse(I<text>)

Parses and verifies the given text. Returns a
B<Config::Generic::UnnamedSection> Object containing the
configuration.

I<text> can also be a scalar reference.

=cut
sub parse
{
    my $this = shift;
    my $text = shift;
    my($config);

    $config = $this->{parser}->startrule($text);

    $this->verify($config, $this->{spec});
    return $config;
}


=item verify(B<$config>, B<$spec>)

Verifies the configuration B<$config> using B<$spec>. B<$spec>
must be a parsed specification of type B<Config::Generic::Section>.

You should not need to call this method directly, it is called by
B<parse()>.

=cut
sub verify
{
    my $this = shift;
    my $config = shift;
    my $spec = shift;

    my($element, $specelem, $secnames, $dirnames);

    my $allowed_elements = $this->create_allowed_elements($spec);

    # Check each element
    foreach $element (@{$config->get_content()}) {

        # Find spec for current element

        # Direktive
        if($element->isa("Config::Generic::Directive")) {
            if($config->is_multiple($element->get_name())) {
                $specelem = $allowed_elements->{$element->get_name()}->{"MultiDirective"};
            } else {
                $specelem = $allowed_elements->{$element->get_name()}->{"SingleDirective"};
                if(!defined $specelem and
                  defined ($specelem = $allowed_elements->{$element->get_name()}->{"MultiDirective"})) {
                    # This is a MultiDirective but was specified only once
                    $config->make_multiple($element->get_name());
                }
            }
        }

        # Unnamed Section
        elsif($element->isa("Config::Generic::UnnamedSection")) {
            if($config->is_multiple($element->get_name())) {
                $specelem = $allowed_elements->{$element->get_name()}->{"MultiSection"};
            } else {
                $specelem = $allowed_elements->{$element->get_name()}->{"SingleSection"};
                if(!defined $specelem and
                   defined ($specelem = $allowed_elements->{$element->get_name()}->{"MultiSection"})) {
                    # This is a MultiSection but was specified only once
                    $config->make_multiple($element->get_name());
                }
            }
        }

        # Named Section
        elsif($element->isa("Config::Generic::NamedSection")) {
            $specelem = $allowed_elements->{$element->get_name()}->{"NamedSection"};
        } else {
            die "Internal error";
        }


        # Unknown element
        if(not defined $specelem) {
            die $element->get_name().": unknown element at line ".
                $element->get_line().".\n";
        }


        if($element->isa("Config::Generic::Section")) {
            # Check section
            $this->verify($element, $specelem);
            # Cache name
            $secnames->{$element->get_name()} = true;
        } else {
            # Check arguments
            my $enough = false;
            my $i;
            for($i = 1; $i < @{$specelem->get_argument()}; $i++) {
                my $specarg = $specelem->get_argument($i);

                # Treat repetition,
                # Check remaining arguments
                if($specarg eq "etc") {
                    $specarg = $specelem->get_argument($i-1);
                    my $j;
                    for($j = $i-1; $j < @{$element->get_argument()}; $j++) {
                        unless($this->re_match($element->get_argument($j),
                                               $specarg)) {
                            die $element->get_name().": invalid argument '".$element->get_argument($j).
                                "' at line ".$element->get_line().".\n";
                        }
                    }
                    $i = $j+1; # avoid failure of argument count check below
                    last;
                }


                # Treat optional arguments
                if($specarg eq "optional") {
                    $enough = true;
                    next;
                }

                # Check argument count
                if($i-1 >= @{$element->get_argument()}) {
                    if($enough) {
                        last;
                    } else {
                        die $element->get_name().": too less arguments at line ".
                            $element->get_line().".\n";
                    }
                }

                # Check argument
                unless($this->re_match($element->get_argument($i-1),
                                       $specelem->get_argument($i))) {
                    die $element->get_name().": invalid argument '".$element->get_argument($i-1).
                        "' at line ".$element->get_line().".\n";
                }
            }

            # Check argument count
            if($i-1 < @{$element->get_argument()}) {
                if($enough) {
                    last;
                } else {
                    die $element->get_name().": too much arguments at line ".
                        $element->get_line().".\n";
                }
            }

            # Cache name
            $dirnames->{$element->get_name()} = true;
        }
    }

    # Ensure required elements
    if(defined $spec->{RequiredDirectives}) {
        foreach my $arg (@{$spec->{RequiredDirectives}->get_argument()}) {
            unless(defined $dirnames->{$arg}) {
                die "Required Directive $arg not specified\n";
            }
        }
    }
    if(defined $spec->{RequiredSections}) {
        foreach my $arg (@{$spec->{RequiredSections}->get_argument()}) {
            unless(defined $secnames->{$arg}) {
                die "Required Section $arg not specified\n";
            }
        }
    }


    return true;
}


#
# check if argument matches re
#
sub re_match
{
    my $this = shift;
    my $string = shift;
    my $re = shift;

    return eval "\$string =~ $re;";
}

# Ensure integrity of the specification
sub verify_spec
{
    my $this = shift;
    my $rootspec = shift;
    my $spec = shift;

    # Integrity of meta section references
    ELEM: foreach my $element (@{$spec->get_content()}) {
        if($element->isa("Config::General::Section")) {
            verify_spec($rootspec, $element);
        }

        elsif($element->get_name() =~ /Ref$/) {
            # Search MetaSection
            foreach my $sec (@{$rootspec->get_content("MetaSection")}) {
                if($sec->get_argument() eq $element->get_argument(1)) {
                    next ELEM; # found
                }
            }
            # Not found
            croak "MetaSection for reference ".$element->get_argument(1).
                " not found at line ".$element->get_line;
        }
    }
    return true;
}

# Create the list of the allowed elements in the
# current nesting level from the spec
# Format is:
#    "allowed_element_name" => { "allowed_types" }
#
sub create_allowed_elements
{
    my $this = shift;
    my $spec = shift;
    my $ret;

    foreach my $type (qw/MultiDirective
                         SingleDirective
                         MultiSectionRef
                         SingleSectionRef
                         NamedSectionRef
                         MultiSection
                         SingleSection
                         NamedSection/) {

        next if not defined $spec->{$type};
        if($type =~ /Section$/) {
            # Allowed elements are stored as keys, because
            # Sections are specified as named sections in
            # the specification
            foreach my $arg (keys %{$spec->{$type}}) {
                $ret->{$arg}->{$type} = $spec->{$type}->{$arg};
            }
        } else {
            # Allowed elements are stored in an anoymous
            # array, because Directives and Section Refs
            # are specified as multiple sections in the
            # specification
            foreach my $element (@{$spec->{$type}}) {
                if($type =~ /^(.+)Ref$/) {
                    # We must dereference
                    my $realtype = $1;
                    $ret->{$element->get_argument(0)}->{$realtype} =
                        $this->{spec}->{MetaSection}->{$element->get_argument(1)};
                } else {
                    $ret->{$element->get_argument(0)}->{$type} = $element;
                }
            }
        }
    }
    return $ret;
}

=back

=head1 CONFIG FILE FORMAT

Lines begining with B<#> and empty lines will be ignored. Whitespace
at the begining and the end of a line will also be ignored.

=head2 Directives

A directive starts with it's name followed by one or more
arguments. An equalsign is optional. The arguments are separated by
whitespace and an optimal comma B<,>. If you need commas or whitespace
as part of an argument, you have to quote it using B<"> or B<'>.

Some possible examples:

 user    max
 password  = mfox
 Sisters = Tina, Hanni, Nanni
 user "second value"

=head2 Sections

You can define a B<section> of directives. A B<section> looks much
like a section in the wellknown apache config format. It starts with
E<lt>B<sectionname>E<gt> and ends with E<lt>/B<sectionname>E<gt>. An
example:

 <database>
    host   = muli
    user   = moare
    dbname = modb
    dbpass = D4r_9Iu
 </database>

Sections can also be nested. Here is a more complicated example:

 user   = hans
 passwd = D3rf$
 <jonas>
        user    = tom
        db      = unknown
        <tablestructure>
                index   int(100000)
                allowed ingram
                allowed joice
        </tablestructure>
 </jonas>

=head2 Named Sections

You can also specify sections with an argument, called "Named Sections":

 <Directory /usr/frisco>
        Limit Deny
        Options ExecCgi Index
 </Directory>
 <Directory /usr/frik>
        Limit DenyAll
        Options None
 </Directory>

You cannot have more than one named block with the same name and
argument.

Named sections are always allowed multiple times -- anything else
wouldn't make sense.

=head2 Here Documents

You can also define a config value as a so called "here-document". You must tell
the module an identifier which identicates the end of a here document. An
identifier must follow a "<<".

Example:

 message <<EOF
   we want to
   remove the
   homedir of
   root.
 EOF

Everything between the two "EOF" strings will be in the option I<message>.

=head1 THE CONFIG SPECIFICATION

The config specification specifies the format of the configuration
file you want to parse. The specification is written in the same
language as the configuration itself.

Example:

 SingleDirective user /\w+/
 MultiDirective alias /w+/

 <SingleSection home>
     SingleDirective street /\w+/
     SingleDirective number /\d+/
 </SingleSection>

 RequiredDirectives user

This specification describes a configuration file with 6 allowed
elements. On "top level" you can use the directives B<user> and B<alias>,
both accept one argument conforming to the regular expression B<\w+>.
The B<user> directive is allowed only once, the B<alias> directive
can be specified multiple times. While the B<alias> directive can
be omitted, the B<user> directive is required.

There is also a section named B<home> allowed. It can be specified
zero or one times and doesn't accept an argument. Inside the section, the
directives B<street> and B<number> are accepted.

Each allowed directive and section in the specification is now
explained in detail:

=head2 SingleDirective

This directive can be specified anywhere. It describes a directive
that is allowed once in the current nesting level.

B<SingleDirective> accepts an unlimited number auf arguments. The
first argument is the name of the described directive. The following
arguments are regular expressions, one for each required parameter
of the described directive (a parameter of the described directive
must match the corresponding regular expression).

The special "re" B<optional> specifies, that the following arguments
can be omitted in the described directive.

The special "re" B<etc> specifies, that the following last described
argument can be repeated endlessly.

=head2 MultiDirective

This directive can be specified anywhere. It describes a directive
that is allowed multiple times in the current nesting level.

Look at B<SingleDirective> for a description of the arguments.

=head2 RequiredDirectives

This directive can be specified anywhere. It specifies
other directives that must be present inside the current
nesting level.

=head2 RequiredSections

This directive can be specified anywhere. It specifies
sections that must be present inside the current
nesting level.

=head2 <MultiSection I<name>>

This named section specifies an unnamed section I<name>
that can be specified multiple times inside the current
nesting level.

You can use all described sections and directives except
B<MetaSection> inside this section to specify the allowed
content of the section.

=head2 <SingleSection I<name>>

This named section specifies an unnamed section I<name> that can be
specified once inside the current nesting level.

You can use all described sections and directives except
B<MetaSection> inside this section to specify the allowed content of
the section.

=head2 <NamedSection I<name>>

This named section specifies an named section I<name> that can be
specified once (or multiple times with different arguments, of course)
inside the current nesting level.

You can use all described sections and directives except
B<MetaSection> inside this section to specify the allowed content of
the section.

=head2 <MetaSection I<name>>

This named section specifies a "meta" section named I<name>. It must
be used top-level, outside from any section. It doesn't specify an
element in the described configuration. Instead, the meta section can
be referenced inside the specification to avoid duplicate code (when
sections with different names must contain the same elements) and to
implement recursion.

A meta section can be referenced with B<MultiSectionRef>, B<SingleSectionRef>
and B<NamedSectionRef>.

You can use all described sections and directives except
B<MetaSection> itself inside this section to specify the allowed
content of the section.

Here is an example that specifies two Sections that both must
contain one directive with a numeric argument:

 <MetaSection numeric>
     SingleDirective number /\d+/
     RequiredDirectives number
 </MetaSection>

 SingleSectionRef section1 numeric
 SingleSectionRef section2 numeric

And here is an example to allow infinite nesting:

 <MetaSection nested>
     NamedSectionRef section nested
     SingleDirective flag /(true|false)/
 </MetaSection>
 NamedSectionRef section nested

A valid configuration file for this specification could be:

 <section outer>
     flag true
     <section inner1>
         flag false
     </section>
     <section inner2>
         <section deepInside>
              flag true
         </section>
     </section>
 </section>

=head2 MultiSectionRef

This directive can be specified anywhere. It specifies an unnamed
section that can be used multiple times inside the current nesting
level.

While B<MultiSection> uses a Section to define a section,
B<MultiSectionRef> expects the name of a meta section as its second
argument. The first argument must be the name of the
described section.

=head2 SingleSectionRef

This directive can be specified anywhere. It specifies an unnamed
section that can be used once inside the current nesting
level.

While B<SingleSection> uses a Section to define a section,
B<SingleSectionRef> expects the name of a meta section as its second
argument. The first argument must be the name of the
described section.

=head2 NamedSectionRef

This directive can be specified anywhere. It specifies a named
section that can be used inside the current nesting
level.

While B<NamedSection> uses a Section to define a section,
B<NamedSectionRef> expects the name of a meta section as its second
argument. The first argument must be the name of the
described section.

=head2 The spec in the spec

The specification format can be expressed in its own. Here it
is, be proud when you can understand it :-)

 MultiDirective SingleDirective /\w+/ /(etc|optional|\/.+\/i?)/ etc
 MultiDirective MultiDirective /\w+/ /(etc|optional|\/.+\/i?)/ etc

 SingleDirective RequiredDirectives /w+/ etc
 SingleDirective RequiredSections /w+/ etc

 MultiSectionRef MultiSection section
 MultiSectionRef SingleSection section
 MultiSectionRef NamedSection section

 NamedSectionRef MetaSection section

 <MetaSection section>
     MultiDirective SingleDirective /\w+/ /\/.+\/i?/ optional /(etc|optional|\/.+\/i?)/ etc
     MultiDirective MultiDirective /\w+/ /\/.+\/i?/ optional /(etc|optional|\/.+\/i?)/ etc

     SingleDirective RequiredDirectives /w+/ etc
     SingleDirective RequiredSections /w+/ etc

     MultiSectionRef MultiSection section
     MultiSectionRef SingleSection section
     MultiSectionRef NamedSection section

     MultiDirective MultiSectionRef /w+/ /w+/
     MultiDirective SingleSectionRef /w+/ /w+/
     MultiDirective NamedSectionRef /w+/ /w+/
 </MetaSection>

Ok, there are still some caveeats that are checked "manually":

1. Each *SectionRef must have a corresponding MetaSection.

2. The regular expression for identifies (section and directive names)
is slightly more complex than shown here.

3. You must not specify B<etc> before <optional> in the parameter
specification.

4. You must insert at least one "regular parameter" between B<optional>
and B<etc>


=head1 BUGS

None known yet. But they probably exist because the module is very new
and untested. So please report anything suspecious you find.

=head1 TODO

Take a look at the sources and fix everything mentioned as
TODO in the comments.

Implement more sanity checks of the config specification (the 4 mentioned
above aren't checked yet)

Implement references to parameter specifications in the configuration
(similar to section references).

=head1 SEE ALSO

L<Config::Generic::Element>,
L<Config::Generic::Section>,
L<Config::Generic::Directive>,
L<Config::Generic::UnnamedSection>,
L<Config::Generic::NamedSection>,
L<Config::Generic::TieWrapper>,
L<Config::Generic::Parser>

=head1 AUTHOR

Nikolaus Rath, E<lt>Nikolaus@rath.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2003 by Nikolaus Rath

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;

__DATA__

 MultiDirective SingleDirective /\w+/ /(etc|optional|\/.+\/i?)/ etc
 MultiDirective MultiDirective /\w+/ /(etc|optional|\/.+\/i?)/ etc

 SingleDirective RequiredDirectives /\w+/ etc
 SingleDirective RequiredSections /\w+/ etc

 NamedSectionRef MultiSection section
 NamedSectionRef SingleSection section
 NamedSectionRef NamedSection section

 MultiDirective MultiSectionRef /\w+/ /\w+/
 MultiDirective SingleSectionRef /\w+/ /\w+/
 MultiDirective NamedSectionRef /\w+/ /\w+/

 NamedSectionRef MetaSection section

 <MetaSection section>
     MultiDirective SingleDirective /\w+/ /\/.+\/i?/ optional /(etc|optional|\/.+\/i?)/ etc
     MultiDirective MultiDirective /\w+/ /\/.+\/i?/ optional /(etc|optional|\/.+\/i?)/ etc

     SingleDirective RequiredDirectives /\w+/ etc
     SingleDirective RequiredSections /\w+/ etc

     MultiSectionRef MultiSection section
     MultiSectionRef SingleSection section
     MultiSectionRef NamedSection section

     MultiDirective MultiSectionRef /\w+/ /\w+/
     MultiDirective SingleSectionRef /\w+/ /\w+/
     MultiDirective NamedSectionRef /\w+/ /\w+/
 </MetaSection>
