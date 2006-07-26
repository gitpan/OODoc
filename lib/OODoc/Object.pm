
package OODoc::Object;
use vars '$VERSION';
$VERSION = '0.93';

use strict;
use warnings;

use Carp;


#-------------------------------------------


sub new(@)
{   my $class = shift;

    my %args = @_;
    my $self = (bless {}, $class)->init(\%args);

    if(my @missing = keys %args)
    {   local $" = ', ';
        carp "WARNING: Unknown ".(@missing==1?'option':'options')." @missing";
    }

    $self;
}

sub init($)
{   my ($self, $args) = @_;
    $self->{OO_extends} = [];
    $self;
}

#-------------------------------------------


sub extends(;$)
{   my $self = shift;
    my $ext  = $self->{OO_extends};
    if(@_)
    {   push @$ext, @_;
    }

    wantarray ? @$ext : $ext->[0];
}

#-------------------------------------------


sub mkdirhier($)
{   my $thing = shift;
    my @dirs  = File::Spec->splitdir(shift);
    my $path  = $dirs[0] eq '' ? shift @dirs : '.';

    while(@dirs)
    {   $path = File::Spec->catdir($path, shift @dirs);
        die "Cannot create $path $!"
            unless -d $path || mkdir $path;
    }

    $thing;
}

#-------------------------------------------


sub filenameToPackage($)
{   my ($thing, $package) = @_;
    $package =~ s!^lib/!!;
    $package =~ s#/#::#g;
    $package =~ s/\.(pm|pod)$//g;
    $package;
}

#-------------------------------------------


my %packages;
my %manuals;

sub addManual($)
{   my ($self, $manual) = @_;

    confess "ERROR: manual definition requires manual object"
        unless ref $manual && $manual->isa('OODoc::Manual');

    push @{$packages{$manual->package}}, $manual;
    $manuals{$manual->name} = $manual;
    $self;
}

#-------------------------------------------


sub mainManual($)
{  my ($self, $name) = @_;
   (grep {$_ eq $_->package} $self->manualsForPackage($name))[0];
}

#-------------------------------------------


sub manualsForPackage($)
{   my ($self,$name) = @_;
    $name ||= 'doc';
    defined $packages{$name} ? @{$packages{$name}} : ();
}

#-------------------------------------------


sub manuals() { values %manuals }

#-------------------------------------------


sub manual($) { $manuals{ $_[1] } }

#-------------------------------------------


sub packageNames() { keys %packages }

1;
