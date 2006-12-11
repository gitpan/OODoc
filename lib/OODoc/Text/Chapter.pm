# Copyrights 2003-2006 by Mark Overmeer. For contributors see ChangeLog.
# See the manual pages for details on the licensing terms.
# Pod stripped from pm file by OODoc .

package OODoc::Text::Chapter;
use vars '$VERSION';
$VERSION = '0.96';
use base 'OODoc::Text::Structure';

use strict;
use warnings;

use List::Util 'first';
use Carp;


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

sub findEntry($)
{   my ($self, $name) = @_;
    return $self if $self->name eq $name;

    foreach my $section ($self->sections)
    {   my $entry = $section->findEntry($name);
        return $entry if defined $entry;
    }

    ();
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

1;
