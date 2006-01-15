package Config::Generic::ImmutableHash;

use Carp;
use constant true => 1;
use constant false => 0;

# An unmodifiable hash
sub TIEHASH
{
    my $class = shift;
    my $obj = shift;

    $class = ref $class || $class;

    # TODO: Should we create a new object?
    bless $obj, $class;

    return $obj;
}

sub FETCH
{
    my $this = shift;
    my $key = shift;

    return $this->{$key};
}

sub STORE
{
    my $this = shift;
    my $key = shift;
    my $value = shift;

    carp("Cannot modify section");
}

sub DELETE
{
    my $this = shift;
    my $key = shift;

    carp("Cannot modify section");
}

sub CLEAR
{
    my $this = shift;
    carp("Cannot modify section");
}

sub EXISTS
{
    my $this = shift;
    my $key = shift;

    return exists $this->{$key};
}

sub FIRSTKEY
{
    my $this = shift;

    keys %$this;

    return each %$this;
}

sub NEXTKEY
{
    my $this = shift;

    return each %$this;
}

sub DESTROY { return true; }
sub UNTIE { return true; }

1;
