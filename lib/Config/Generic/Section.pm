=head1 NAME

Config::Generic::Section - Class representing configuration sections

=head1 SYNOPSIS

 use Config::Generic;

 my $parser = new Config::Generic($grammar);
 my $config = $parser->parse($text);

 # Root is always an unnamed section
 $config->isa("Config::Generic::Section")

 # Object oriented access
 $config->get("Flag");

 # Tied access
 tie %$ref, "Config::Generic::TieWrapper",
     { Config => $config };
 $ref->{"Flag"}


=head1 DESCRIPTION

This class represents a configuration section. It is
inherited from B<Config::Generic::Element>.

=head1 METHODS

=over

=cut
package Config::Generic::Section;

use strict;
use warnings;
use constant true => 1;
use constant false => 0;
use base 'Config::Generic::Element';
use Carp;

use Config::Generic::ImmutableArray;
use Config::Generic::ImmutableHash;
use Config::Generic::TieWrapper;

=item new($name, $content, $line)

Constructs a new section. B<$line> is the line in that the directive
was specified. B<$argument> is an anonymous array holding all elements
(type: B<Config::Generic::Element>) the section contains. B<$name> is
the name of the section.

=cut
sub new
{
    my $class = shift;
    my $name = shift;
    my $content = shift;
    my $line = shift;
    my $this = $class->SUPER::new($name, $line);

    # Filter out comments
    $this->{content} = [ grep ref, @$content ];

    # Store the names that should always be treated
    # as multiple values
    $this->{multiple} = {};

    return $this;
}

# Count the number of elements with the given
# name
# Named Sections with different arguments (but with
# the same names) only count as one.
sub count_elements
{
    my $this = shift;
    my $name = shift;
    my $bundle_nsections = shift;

    my $count = 0;
    my $counted_named_section = false;

    foreach my $element (@{$this->{content}}) {
        if($element->get_name() ne $name) {
            next;
        }

        if($element->isa("Config::Generic::NamedSection") and
           $bundle_nsections) {
            if($counted_named_section) {
                next;
            } else {
                $count++;
                $counted_named_section = true;
            }
        } else {
            $count++;
        }
    }

    return $count;
}


=item get_content([$name])

Return a reference to an array holding the contained
elements.

If $name is specified, returns only those elements with
that name.

=cut
sub get_content
{
    my $this = shift;
    my $name = shift;


    if(defined $name) {
        return $this->get_elements($name);
    } else {
        return [ @{$this->{content}} ];
    }
}

=item set_content($content)

Sets the content of the section. $content must be
an array reference.  The array must contain objects
of type B<Config::Generic::Element>.

=cut
sub set_content
{
    my $this = shift;
    $this->{content} = shift;
    return true;
}

=item is_multiple($name, [$bunddle_nsections])

Returns true if there is more than one element in the section with the
given name.

If $bunddle_nsections is true, named sections are bundled and count
only as one.

Ignores the multiple mark.

=cut
sub is_multiple {
    my $this = shift;
    my $name = shift;
    my $bundle_nsections = shift;
    defined $bundle_nsections or $bundle_nsections = false;

    return $this->count_elements($name, $bundle_nsections) > 1;
}

=item make_multiple($name)

Marks the name $name as multiple. That means that even if there
is only one element with this name, it is still treated as if
there were multiple elements with this name.

(That means that B<get_element> and the tied access interface would
return an anonymous array)

The B<Config::Generic->verify()> method invokes this method during
verification to ensure that B<MultiDirectives> are treated so even if
they occur only once in the configuration.

=cut
sub make_multiple
{
    my $this = shift;
    my $name = shift;

    $this->{multiple}->{$name} = true;
}

=item unmake_multiple($name)

Removes the multiple mark from the name $name.

Only the mark is removed, if there are really more than one
elements with this name, they are still treated as multiple.

=cut
sub unmake_multiple
{
    my $this = shift;
    my $name = shift;

    delete $this->{multiple}->{$name};
}

=item add_element($element)

Adds the given element to the section.

=cut
sub add_element
{
    my $this = shift;
    my Config::Generic::Element $element = shift;

    push @{$this->{contents}}, $element;
}


=item remove_element($element)

Remove element from the contents of the section

The multiple status can get lost, so maybe you have to call
Config::Section->multiple($name) after this function.

=cut
sub remove_element
{
    my $this = shift;
    my $element = shift;

    my($i);

    for($i = 0; $i < @{$this->{content}}; $i++) {
        if($this->{content}->[$i] == $element) {
            splice @{$this->{content}}, $i, 1;
            $i--;
        }
    }
}

#
# We should implement caching here because this might
# get really slow
#
sub get_elements_tied
{
    my $this = shift;
    my $tieconfig = shift;
    my $key = shift;

    my $matches = [];
    my $named_sections;

    foreach my $element (grep $_->get_name() eq $key, @{$this->{content}}) {
        my $tie;
        if($element->isa("Config::Generic::NamedSection") and
           $tieconfig->{"HashNamedSections"}) {
            # Named Sections are not referenced directly. They
            # must be adressed using an anonymous hash with their
            # argument as the key or using an anonymous array.
            $tie = {};
            tie %$tie, "Config::Generic::TieWrapper",
                { Config => $element,
                  HashNamedSections => $tieconfig->{HashNamedSections},
                  TieDirectives => $tieconfig->{TieDirectives} };
            $named_sections->{$element->get_argument()} = $tie;
        } elsif($element->isa("Config::Generic::Section")) {
            $tie = {};
            tie %$tie, "Config::Generic::TieWrapper",
                  { Config => $element,
                  HashNamedSections => $tieconfig->{HashNamedSections},
                  TieDirectives => $tieconfig->{TieDirectives} };
            push @$matches, $tie;
        } else {
            # Treat directives
            if($tieconfig->{"TieDirectives"} eq "auto") {
                # Tie if multiple args
                if($element->has_multiple_args()) {
                    $tie = [];
                    tie @$tie, "Config::Generic::TieWrapper",
                        { Config => $element,
                          HashNamedSections => $tieconfig->{HashNamedSections},
                          TieDirectives => $tieconfig->{TieDirectives} };
                    push @$matches, $tie;
                } else {
                    push @$matches, $element;
                }
            }elsif($tieconfig->{"TieDirectives"} eq "yes") {
                # Always tie
                $tie = [];
                tie @$tie, "Config::Generic::TieWrapper",
                    { Config => $element,
                      HashNamedSections => $tieconfig->{HashNamedSections},
                      TieDirectives => $tieconfig->{TieDirectives} };
                push @$matches, $tie;
            } else {
                # Never tie
                push @$matches, $element;
            }
        }
    }

    # Now we add the named sections to the result
    if(defined $named_sections) {
        # We must tie this array so it becomes immutable
        my $hash;
        tie %$hash, "Config::Generic::ImmutableHash", $named_sections;
        push @$matches, $hash;
    }

    # We must tie this array so it becomes immutable
    my $ret;
    tie @$ret, "Config::Generic::ImmutableArray", $matches;

    return $ret;
}


#
# We should implement caching here because this might
# get really slow
#
sub get_elements
{
    my $this = shift;
    my $key = shift;

    return [ grep $_->get_name() eq $key, @{$this->{content}} ];
}


=back

=head1 TIED ACCESS

You can access the directive using B<Config::Generic::TieWrapper>. See
the corresponding manpage for details.

=cut
#
# Methods for tied hash access
#
sub FETCH
{
    my $this = shift;
    my $tieconfig = shift;
    my $key = shift;
    my $ret;

    $ret = $this->get_elements_tied($tieconfig, $key);

    if(@$ret == 1 and
       !defined $this->{multiple}->{$key}) {
        $ret = $ret->[0];
    }elsif(@$ret == 0) {
        # No matching element
        return undef;
    }

    return $ret;
}

sub STORE
{
    my $this = shift;
    my $tieconfig = shift;
    my $key = shift;
    my $value = shift;

    my $elements = $this->get_elements_tied($key);

    if(@$elements > 1 or
       defined $this->{multiple}->{$key}) {
        carp("Can't modify multiple element via tied hash");
    }

    unless($elements->[0]->isa("Config::Generic::Directive")) {
        carp("Cannot modify sections");
    }

    $elements->[0]->set_argument($value);
}

sub DELETE
{
    my $this = shift;
    my $tieconfig = shift;
    my $key = shift;

   foreach my $elem (@{$this->get_elements($key)}) {
       $this->remove_element($elem);
   }
}

sub CLEAR
{
    my $this = shift;
    my $tieconfig = shift;
    carp("Clearing configuration hash is not allowed");
}

sub EXISTS
{
    my $this = shift;
    my $tieconfig = shift;
    my $key = shift;

    return @{$this->get_elements($key)} > 0;
}

sub FIRSTKEY
{
    my $this = shift;
    my $tieconfig = shift;

    # Create list of all names (hash to avoid duplicates)
    my $names;
    foreach my $element (@{$this->{content}}) {
        $names->{$element->get_name()} = true;
    }

    # Store the list
    $this->{iterator} = [ keys %$names ];

    return $this->NEXTKEY();
}

sub NEXTKEY
{
    my $this = shift;
    my $tieconfig = shift;
    my $key = pop @{$this->{iterator}};

    if(defined $key) {
        return wantarray ? ($key, $this->FETCH($tieconfig, $key)) : $key;
    } else {
        return wantarray ? () : undef;
    }
}


sub DESTROY { return true; }
sub UNTIE { return true; }

=head1 BUGS

None known yet. But they probably exist because the module is very new
and untested. So please report anything suspecious you find.

=head1 TODO

Nothing :-)

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
