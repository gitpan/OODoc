
package OODoc::Text;
use vars '$VERSION';
$VERSION = '0.07';
use base 'OODoc::Object';

use strict;
use warnings;

use Carp;


#-------------------------------------------


use overload '=='   => sub {$_[0]->unique == $_[1]->unique}
           , '!='   => sub {$_[0]->unique != $_[1]->unique}
           , '""'   => sub {$_[0]->name}
           , 'cmp'  => sub {$_[0]->name cmp "$_[1]"}
           , 'bool' => sub {1};

#-------------------------------------------


my $unique = 1;

sub init($)
{   my ($self, $args) = @_;
    $self->SUPER::init($args) or return;

    $self->{OT_name}     = delete $args->{name};

    my $nr = $self->{OT_linenr} = delete $args->{linenr} or confess;
    $self->{OT_type}     = delete $args->{type} or confess;

    confess "no text container specified for the ".ref($self)." object"
       unless exists $args->{container};   # may be undef
    $self->{OT_container}= delete $args->{container};
    
    $self->{OT_descr}    = delete $args->{description} || '';
    $self->{OT_examples} = [];
    $self->{OT_unique}   = $unique++;

    $self;
}

#-------------------------------------------


#-------------------------------------------


sub name() {shift->{OT_name}}

#-------------------------------------------


sub type() {shift->{OT_type}}

#-------------------------------------------


sub description()
{   my $text  = shift->{OT_descr};
    my @lines = split /^/m, $text;
    shift @lines while @lines && $lines[ 0] =~ m/^\s*$/;
    pop   @lines while @lines && $lines[-1] =~ m/^\s*$/;
    join '', @lines;
}

#-------------------------------------------


sub container(;$)
{   my $self = shift;
    @_ ? ($self->{OT_container} = shift) : $self->{OT_container};
}

#-------------------------------------------


sub manual(;$)
{   my $self = shift;
    @_ ? $self->SUPER::manual(@_)
       : $self->container->manual;
}

#-------------------------------------------


sub unique() {shift->{OT_unique}}

#-------------------------------------------


sub where()
{   my $self = shift;
    ($self->manual->source, $self->{OT_linenr});
}

#-------------------------------------------


sub openDescription() { \shift->{OT_descr} }

#-------------------------------------------


sub findDescriptionObject()
{   my $self   = shift;
    return $self if length $self->description;

    my $extends = $self->extends;
    defined $extends ? $extends->findDescriptionObject : undef;
}

#-------------------------------------------


sub example($)
{   my ($self, $example) = @_;
    push @{$self->{OT_examples}}, $example;
    $example;
}

#-------------------------------------------


sub examples() { @{shift->{OT_examples}} }

#-------------------------------------------



1;
