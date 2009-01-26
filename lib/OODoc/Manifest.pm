# Copyrights 2003-2009 by Mark Overmeer.
#  For other contributors see ChangeLog.
# See the manual pages for details on the licensing terms.
# Pod stripped from pm file by OODoc 1.05.

package OODoc::Manifest;
use vars '$VERSION';
$VERSION = '1.05';

use base 'OODoc::Object';

use strict;
use warnings;

use Carp;
use IO::File;
use File::Basename 'dirname';


use overload '@{}' => sub { [ shift->files ] };
use overload bool  => sub {1};

#-------------------------------------------


sub init($)
{   my ($self, $args) = @_;
    $self->SUPER::init($args) or return;

    my $filename = $self->{OM_filename} = delete $args->{filename};

    $self->{O_files} = {};
    $self->read if defined $filename && -e $filename;
    $self->modified(0);
    $self;
}

#-------------------------------------------


sub filename() {shift->{OM_filename}}

#-------------------------------------------


sub files() { keys %{shift->{O_files}} }

#-------------------------------------------


sub add($)
{   my $self = shift;
    while(@_)
    {   my $add = $self->relative(shift);
        $self->modified(1) unless exists $self->{O_file}{$add};
        $self->{O_files}{$add}++;
    }
    $self;
}

#-------------------------------------------


sub read()
{   my $self = shift;
    my $filename = $self->filename;
    my $file = IO::File->new($filename, "r")
       or die "ERROR: Cannot read manifest file $filename: $!\n";

    my @dist = $file->getlines;
    $file->close;

    s/\s+.*\n?$// for @dist;
    $self->{O_files}{$_}++ foreach @dist;
    $self;
}

#-------------------------------------------


sub modified(;$)
{   my $self = shift;
    @_ ? $self->{OM_modified} = @_ : $self->{OM_modified};
}

#-------------------------------------------


sub write()
{   my $self = shift;
    return unless $self->modified;
    my $filename = $self->filename || return $self;

    my $file = IO::File->new($filename, "w")
      or die "ERROR: Cannot write manifest $filename: $!\n";

    $file->print($_, "\n") foreach sort $self->files;
    $file->close;

    $self->modified(0);
    $self;
}

sub DESTROY() { shift->write }

#-------------------------------------------


sub relative($)
{   my ($self, $filename) = @_;

    my $dir = dirname $self->filename;
    return $filename if $dir eq '.';

    # normalize path for windows
    s!\\!/!g for $filename, $dir;

    if(substr($filename, 0, length($dir)+1) eq "$dir/")
    {   substr $filename, 0, length($dir)+1, '';
        return $filename;
    }

    warn "WARNING: MANIFEST file ".$self->filename
            . " lists filename outside (sub)directory: $filename\n";

    $filename;
}

#-------------------------------------------


1;
