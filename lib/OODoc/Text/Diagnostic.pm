# Copyrights 2003-2013 by [Mark Overmeer].
#  For other contributors see ChangeLog.
# See the manual pages for details on the licensing terms.
# Pod stripped from pm file by OODoc 2.00.

package OODoc::Text::Diagnostic;
use vars '$VERSION';
$VERSION = '2.00';

use base 'OODoc::Text';

use strict;
use warnings;

use Log::Report    'oodoc';


sub init($)
{   my ($self, $args) = @_;
    $args->{type}    ||= 'Diagnostic';
    $args->{container} = delete $args->{subroutine} or panic;

    $self->SUPER::init($args) or return;

    $self;
}

#-------------------------------------------


sub subroutine() { shift->container }

#-------------------------------------------

1;
