
package OODoc::Text::Structure;
use vars '$VERSION';
$VERSION = '0.06';
use base 'OODoc::Text';

use strict;
use warnings;

use Carp;
use List::Util 'first';


#-------------------------------------------


sub init($)
{   my ($self, $args) = @_;
    $self->SUPER::init($args) or return;
    $self->{OTS_subs} = [];
    $self->{OTS_level} = delete $args->{level}
        or croak "ERROR: no level defined for structural component";

    $self;
}

#-------------------------------------------


sub emptyExtension($)
{   my ($self, $container) = @_;

    my $new = ref($self)->new
     ( name      => $self->name
     , linenr    => -1
     , level     => $self->level
     , container => $container
     );
   $new->extends($self);
   $new;
}

#-------------------------------------------


sub level() {shift->{OTS_level}}

#-------------------------------------------


sub niceName()
{   my $name = shift->name;
    $name =~ m/[a-z]/ ? $name : ucfirst(lc $name);
}

#-------------------------------------------


sub path() { confess "Not implemented" }

#-------------------------------------------


sub findEntry($) { confess "Not implemented" }

#-------------------------------------------


sub all($@)
{   my ($self, $method) = (shift, shift);
    $self->$method(@_);
}

#-------------------------------------------


sub isEmpty()
{   my $self = shift;

    return 1 if $self->description =~ m/^\s*$/;
    return 0 if $self->examples || $self->subroutines;

    my @nested = $self->isa('OODoc::Text::Capter')  ? $self->sections
               : $self->isa('OODoc::Text::Section') ? $self->subsections
               :                                      ();
    first { ! $_->isEmpty } @nested;
}

#-------------------------------------------


#-------------------------------------------


sub addSubroutine(@)
{  my $self = shift;
   push @{$self->{OTS_subs}}, @_;
   $_->container($self) for @_;
   $self;
}

#-------------------------------------------


sub subroutines() { @{shift->{OTS_subs}} }

#-------------------------------------------


sub subroutine($)
{   my ($self, $name) = @_;
    first {$_->name eq $name} $self->subroutines;
}

#-------------------------------------------


sub setSubroutines($)
{   my $self = shift;
    $self->{OTS_subs} = shift || [];
}

#-------------------------------------------



1;
