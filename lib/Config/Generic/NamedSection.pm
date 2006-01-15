package Config::Generic::NamedSection;

use strict;
use warnings;
use constant true => 1;
use constant false => 0;

use base 'Config::Generic::Section';

sub new
{
    my $class = shift;
    my $name = shift;
    my $argument = shift;
    my $content = shift;
    my $line = shift;
    my $this = $class->SUPER::new($name, $content, $line);

    $this->{argument} = $argument;
    $this->{content} = $content;

    return $this;
}

sub get_argument
{
    return shift()->{argument};
}

sub set_argument
{
    my $this = shift;
    $this->{argument} = shift;
    return true;
}


1;
