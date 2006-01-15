package Config::Generic::ImmutableArray;

use Carp;
use constant true => 1;
use constant false => 0;

# An unmodifiable array
sub TIEARRAY
{
    my $class = shift;
    my $obj = shift;

    $class = ref $class || $class;

    # TODO: Should we create a new object?
    bless $obj, $class;

    return $obj;
}

sub FETCH {
    my $this = shift; my $index = shift;
    return $this->[$index];
}
sub STORE {
    my $this = shift; my $index = shift;
    carp("Cannot modify section");
}
sub FETCHSIZE {
    my $this = shift;
    return scalar @{$this}
}
sub STORESIZE {
    my $this = shift; my $index = shift;
    carp("Cannot modify section");
}
sub EXISTS {
    my $this = shift; my $index = shift;
    return exists $this->[$index];
}
sub DELETE {
    my $this = shift; my $index = shift;
    carp("Cannot modify section");
}
sub CLEAR {
    my $this = shift;
    carp("Cannot modify section");
}
sub PUSH {
    my $this = shift;
    carp("Cannot modify section");
}
sub POP {
    my $this = shift;
    carp("Cannot modify section");
}
sub SHIFT {
    my $this = shift;
    carp("Cannot modify section");
}
sub UNSHIFT {
    my $this = shift;
    carp("Cannot modify section");
}
sub SPLICE {
    my $this = shift;
    carp("Cannot modify section");
}

sub DESTROY { return true; }
sub UNTIE { return true; }

1;
