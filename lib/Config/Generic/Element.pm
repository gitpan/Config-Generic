=head1 NAME

Config::Generic::Element - Base class for configuration elements

=head1 SYNOPSIS

 use Config::Generic;

 my $parser = new Config::Generic($grammar);
 my $config = $parser->parse($text);

 # $config->isa("Config::Generic::Element")

=head1 DESCRIPTION

This is the base class of all configuration elements.

=head1 METHODS

=over

=cut

package Config::Generic::Element;

use strict;
use warnings;
use constant true => 1;
use constant false => 0;

=item new($name, $line)

Constructs a new configuration element. I can't see any
reason why you should call this method. Maybe you should
try one of the inherited classes?

=cut
sub new
{
    my $class = shift;
    my $name = shift;
    my $line = shift;
    my($this);

    $class = ref $class || $class;

    $this = {
             name => $name,
             line => $line
             };

    bless $this, $class;

    return $this;
}


=item get_name()

Returns the name of the configuration element.

=cut
sub get_name
{
    my $this = shift;
    return $this->{name};
}

=item get_line()

Returns the line in that the current configuration element
was specified (if the element is a section it returns the line
in that the section begins).

=cut
sub get_line
{
    my $this = shift;
    return $this->{line};
}


=back

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
