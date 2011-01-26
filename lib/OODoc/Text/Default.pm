# Copyrights 2003-2011 by Mark Overmeer.
#  For other contributors see ChangeLog.
# See the manual pages for details on the licensing terms.
# Pod stripped from pm file by OODoc 1.06.

package OODoc::Text::Default;
use vars '$VERSION';
$VERSION = '1.06';

use base 'OODoc::Text';

use strict;
use warnings;

use Carp;


sub init($)
{   my ($self, $args) = @_;
    $args->{type}    ||= 'Default';
    $args->{container} = delete $args->{subroutine} or confess;

    $self->SUPER::init($args) or return;

    $self->{OTD_value} = delete $args->{value};
    confess unless defined $self->{OTD_value};

    $self;
}

#-------------------------------------------


sub subroutine() { shift->container }

#-------------------------------------------


sub value() { shift->{OTD_value} }

#-------------------------------------------

1;
