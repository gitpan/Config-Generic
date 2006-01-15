=head1 NAME

Config::Generic::TieWrapper - Tied access to configuration elements

=head1 SYNOPSIS

 use Config::Generic;

 my $parser = new Config::Generic($grammar);
 my $config = $parser->parse($text);

 # Tied access
 tie %$ref, "Config::Generic::TieWrapper",
     { Config => $config };

 $directive = $ref->{"Flag"}        # Directive access

 $arg = $directive->get_argument(0) # Argument access #1
 $arg = $directive->[0]             # Argument access #1

 $section = $ref->{"Section"}       # Unnamed Section Access

 $section = $ref->{"Section"}->{"Name"} # Named Section Access #1
 $section = $ref->{"Section"}->[0] # Named Section Access #2

 # Access to multivalues via additional arrays:
 $directive = $ref->{"Flag"}->[$index];
 $section = $ref->{"Section"}->[$index];

=head1 DESCRIPTION

This class can be used to access configuration elements over
tied hashes and arrays instead of the object orientated interface.

Please note that you cannot modify the configuration via the
tied interface. You have to change to the object orientated
interface to do that. Or you can make a deep clone of the hash
and modify the clone. But don't forget that the clone has lost
any associations to section (and eventually directive) objects.

The constructor expects an anonymous hash as its single argument.
The following keys are defined:

=over 4

=item Config

Refers to the configuration object that should be accessed using
the tied interface. This key is mandatory.

=item HashNamedSessions

Valid values are true and false.

If this is B<true>, Named Sections are represented as hashes with
their argument as keys.

If this is B<false>, the are accessed like regular multivalues (as
anonymous arrays).

=item TieDirectives

Valid values are B<yes>, B<no>, and B<auto>.

If you specify no, directives will not be tied. You have to
use the object oriented interface to access them.

If you specify auto, directives will only be tied if they
have more than one argument. This is nice because you can
access a directive with one argument "literally", because it
overloads the stringification operator.

If you specify yes, directive object will always be tied.
You must access the arguments as elements of an anoymous hash.

=back

=head1 REPRESENTATION

Sections are represented as hashes. The keys correspond to the names
of the elements contained in the section. If there is more than one
element with the same name or if the name was marked as multiple in
the section (see L<Config::Generic::Section>), the associated value is
an anonymous array containing the all elements with the
name. Otherwise the value references the element directly.

If you activated the B<HashNamedSections> option, the behaviour is a
little bit different. Multiple Named Sections with different arguments
but identical names are now stored in another hash using their
arguments as keys. This hash is then added to the returned array (if
there are other elements with the same name or if the name was
marked as multiple) or otherwise returned directly.

Each section retrieved via the tied interface is also tied. If you
want to access the real section object, you have to use the B<tied>
function:

 ref($root->{"Section"}) eq "HASH" # or ARRAY
 tied($root->{"Section"})->isa("Config::Generic::Section");

Depending on the value of B<TieDirectives>, directives fetched
via the tied interface are also tied or not. See above for details.

=head1 IMPLEMENTATION NOTES

This class is only a wrapper. The real functionality is delegated
to B<Config::Generic::Section> and B<Config::Generic::Directive>.

head1 METHODS

=over

=cut
package Config::Generic::TieWrapper;

use Carp;
use constant true => 1;
use constant false => 0;

sub new
{
    my $class = shift;
    my $tieconfig = shift;

    $class = ref $class || $class;

    # Defaults
    $tieconfig->{HashNamedSections} = 1 unless defined $tieconfig->{HashNamedSections};
    $tieconfig->{TieDirectives} = "auto" unless defined $tieconfig->{TieDirectives};

    unless(defined $tieconfig->{Config}) {
        carp("No configuration object specified");
    }

    # TODO: Should we create a new object?
    bless $tieconfig, $class;

    return $tieconfig;
}

sub TIEHASH {
    return new(@_);
}

sub TIEARRAY {
    return new(@_);
}

# Delegate methods
sub AUTOLOAD {
    no strict 'refs';
    my $this = shift;
    my $sub = $AUTOLOAD;

    unless($sub =~ /^Config::Generic::TieWrapper::(.+)$/) {
        carp("Unknown method: $sub");
    }

    return $this->{Config}->$1($this, @_);
}
1;
