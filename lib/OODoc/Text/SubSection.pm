# Copyrights 2003-2009 by Mark Overmeer.
#  For other contributors see ChangeLog.
# See the manual pages for details on the licensing terms.
# Pod stripped from pm file by OODoc 1.05.

package OODoc::Text::SubSection;
use vars '$VERSION';
$VERSION = '1.05';

use base 'OODoc::Text::Structure';

use strict;
use warnings;

use Carp;


sub init($)
{   my ($self, $args) = @_;
    $args->{type}      ||= 'Subsection';
    $args->{container} ||= delete $args->{section} or confess;
    $args->{level}     ||= 3;

    $self->SUPER::init($args) or return;
    $self->{OTS_subsubsections} = [];
    $self;
}

sub findEntry($)
{  my ($self, $name) = @_;
   $self->name eq $name ? $self : ();
}

#-------------------------------------------


sub section() { shift->container }


sub chapter() { shift->section->chapter }

sub path()
{   my $self = shift;
    $self->section->path . '/' . $self->name;
}

#-------------------------------------------


sub subsubsection($)
{   my ($self, $thing) = @_;

    if(ref $thing)
    {   push @{$self->{OTS_subsubsections}}, $thing;
        return $thing;
    }

    first {$_->name eq $thing} $self->subsubsections;
}


sub subsubsections(;@)
{   my $self = shift;
    if(@_)
    {   $self->{OTS_subsubsections} = [ @_ ];
        $_->container($self) for @_;
    }

    @{$self->{OTS_subsubsections}};
}


1;

1;
