# Copyrights 2003-2011 by Mark Overmeer.
#  For other contributors see ChangeLog.
# See the manual pages for details on the licensing terms.
# Pod stripped from pm file by OODoc 1.06.

package OODoc::Parser;
use vars '$VERSION';
$VERSION = '1.06';

use base 'OODoc::Object';

use strict;
use warnings;

use Carp;
use List::Util qw/first/;


#-------------------------------------------


sub init($)
{   my ($self, $args) = @_;
    $self->SUPER::init($args) or return;

    my $skip = delete $args->{skip_links} || [];
    my @skip = map { ref $_ eq 'Regexp' ? $_ : qr/^\Q$_\E(?:\:\:|$)/ }
       ref $skip eq 'ARRAY' ? @$skip : $skip;
    $self->{skip_links} = \@skip;

    $self;
}

#-------------------------------------------


sub parse(@) { confess }

#-------------------------------------------


sub skipManualLink($)
{   my ($self, $package) = @_;
    (first { $package =~ $_ } @{$self->{skip_links}}) ? 1 : 0;
}


sub cleanup($$$)
{   my ($self, $formatter, $manual, $string) = @_;

    return $self->cleanupPod($formatter, $manual, $string)
       if $formatter->isa('OODoc::Format::Pod');

    return $self->cleanupHtml($formatter, $manual, $string)
       if $formatter->isa('OODoc::Format::Html');

    croak "ERROR: The formatter type ".ref($formatter)
        . " is not known for cleanup\n";

    $string;
}


1;

