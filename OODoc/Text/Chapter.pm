
package OODoc::Text::Chapter;
use vars '$VERSION';
$VERSION = '0.04';
use base 'OODoc::Text::Structure';

use strict;
use warnings;

use List::Util 'first';
use Carp;


#-------------------------------------------


#-------------------------------------------


sub init($)
{   my ($self, $args) = @_;
    $args->{type}       ||= 'Chapter';
    $args->{container}  ||= delete $args->{manual} or confess;
    $args->{level}      ||= 1;

    $self->SUPER::init($args) or return;

    $self->{OTC_sections} = [];

    $self;
}

#-------------------------------------------

sub manual() {shift->container}

#-------------------------------------------

sub path() {shift->name}

#-------------------------------------------

sub findSubroutine($)
{   my ($self, $name) = @_;
    my $sub = $self->SUPER::findSubroutine($name);
    return $sub if defined $sub;

    foreach my $section ($self->sections)
    {   my $sub = $section->findSubroutine($name);
        return $sub if defined $sub;
    }

    undef;
}

#-------------------------------------------

sub all($@)
{   my $self = shift;
    ($self->SUPER::all(@_), map {$_->all(@_)} $self->sections);
}

#-------------------------------------------


#-------------------------------------------


sub section($)
{   my ($self, $thing) = @_;

    if(ref $thing)
    {   push @{$self->{OTC_sections}}, $thing;
        return $thing;
    }

    first {$_->name eq $thing} $self->sections;
}

#-------------------------------------------


sub sections()
{  my $self = shift;
   if(@_)
   {   $self->{OTC_sections} = [ @_ ];
       $_->container($self) for @_;
   }
   @{$self->{OTC_sections}};
}

#-------------------------------------------


#-------------------------------------------

sub allExamples()
{   my $self = shift;

    ( $self->examples
    , map({$_->allExamples} $self->sections)
    , map({$_->examples}    $self->subroutines)
    );
}

#-------------------------------------------

1;
