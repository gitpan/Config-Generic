=head1 NAME

Config::Generic::Directive - Class representing configuration directives

=head1 SYNOPSIS

 use Config::Generic;

 my $parser = new Config::Generic($grammar);
 my $config = $parser->parse($text);

 # Flag should be a directive, of course
 # $config->get("Flag")->isa("Config::Generic::Directive")

 # Object oriented access
 $directive = $config->get("Flag");
 $directive->get_argument(1);
 $directive->set_argument("foo", 2);

 # Tied access
 tie %$ref, "Config::Generic::TieWrapper",
     { Config => $config,
       TieDirectives => "no" };
 $ref->{"Flag"}->get_argument(1);

 # or

 tie %$ref, "Config::Generic::TieWrapper",
     { Config => $config,
       TieDirectives => "yes" };
 $ref->{"Flag"}->[1]; # Second argument


=head1 DESCRIPTION

This class represents a single configuration directive. It is
inherited from B<Config::Generic::Element>.

=head1 METHODS

=over

=cut
package Config::Generic::Directive;

use strict;
use warnings;
use constant true => 1;
use overload '""' => "as_string";
use constant false => 0;
use Carp;
use base 'Config::Generic::Element';

=item new($name, $argument, $line)

Constructs a new directive. B<$line> is the line in that
the directive was specified. B<$argument> is an anonymous
array holding all arguments of the directive. B<$name> is
the name.

=cut
sub new
{
    my $class = shift;
    my $name = shift;
    my $argument = shift;
    my $line = shift;
    my $this = $class->SUPER::new($name, $line);

    $this->{argument} = $argument;

    return $this;
}

=item has_multiple_args

Returns true if the directive has more than one
argument

=cut
sub has_multiple_args
{
    return @{shift()->{argument}} > 1;
}


=item get_argument([$index])

Return a reference to an array holding the
arguments if no parameter was given.

Else return the requested argument.

=cut
sub get_argument
{
    my $this = shift;
    my $index = shift;

    if(defined $index) {
        return $this->{argument}->[$index];
    } else {
        return [ @{$this->{argument}} ]; # Return a copy
    }
}

=item set_argument($value, [$index])

If $index was given: Set the specified
argument to this value.

Else: Set the argument list to this value
($value must be an arrayref)

=cut
sub set_argument
{
    my $this = shift;
    my $value = shift;
    my $index = shift;

    if(defined $index) {
        $this->{argument}->[$index] = $value;
    } else {
        unless(ref $value eq "ARRAY") {
            carp("Invalid parameter, must be arrayref");
        }
        $this->{argument} = [ @{$value} ];
    }
    return true;
}


=item as_string

Can only be called if the directive has only 1 argument.
Returns the argument.

This method is used to overload the string interpolation,
so you can do

 print $object

to print the argument

=cut
sub as_string
{
    my $this = shift;
    if($this->has_multiple_args()) {
        carp("Directive has (unexpectedly) more than one argument");
    }
    return $this->{argument}->[0];
}

=back

=head1 TIED ACCESS

You can access the directive using B<Config::Generic::TieWrapper>. See
the corresponding manpage for details.

=cut
#
# Methods for tied array access
#
sub FETCH {
    my $this = shift; my $tieoptions = shift; my $index = shift;
    return $this->{argument}->[$index];
}
sub STORE {
    my $this = shift; my $tieoptions = shift; my $index = shift;
    $this->{argument}->[$index] = shift;
}
sub FETCHSIZE {
    my $this = shift;my $tieoptions = shift;
    return scalar @{$this->{argument}}
}
sub STORESIZE {
    my $this = shift;my $tieoptions = shift;  my $index = shift;
    $#{$this->{argument}} = $index;
}
sub EXISTS {
    my $this = shift;my $tieoptions = shift;  my $index = shift;
    return exists $this->{argument}->[$index];
}
sub DELETE {
    my $this = shift;my $tieoptions = shift;  my $index = shift;
    delete $this->{argument}->[$index];
}
sub CLEAR {
    my $this = shift;my $tieoptions = shift;
    $this->{argument} = [];
}
sub PUSH {
    my $this = shift;my $tieoptions = shift;
    push @{$this->{argument}}, @_;
}
sub POP {
    my $this = shift;my $tieoptions = shift;
    return pop @{$this->{argument}}
}
sub SHIFT {
    my $this = shift;my $tieoptions = shift;
    return shift @{$this->{argument}};
}
sub UNSHIFT {
    my $this = shift;my $tieoptions = shift;
    return unshift @{$this->{argument}}, @_;
}
sub SPLICE {
    my $this = shift;my $tieoptions = shift;
    return splice @{$this->{argument}}, @_;
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
