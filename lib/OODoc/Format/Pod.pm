# Copyrights 2003-2009 by Mark Overmeer.
#  For other contributors see ChangeLog.
# See the manual pages for details on the licensing terms.
# Pod stripped from pm file by OODoc 1.05.
package OODoc::Format::Pod;
use vars '$VERSION';
$VERSION = '1.05';

use base 'OODoc::Format';

use strict;
use warnings;

use File::Spec   ();
use Carp         qw/confess/;
use List::Util   qw/max/;
use Pod::Escapes qw/e2char/;


sub link($$;$)
{   my ($self, $manual, $object, $text) = @_;
    $object = $object->subroutine if $object->isa('OODoc::Text::Option');
    $object = $object->subroutine if $object->isa('OODoc::Text::Default');
    $object = $object->container  if $object->isa('OODoc::Text::Example');
    $object = $object->container  if $object->isa('OODoc::Text::Subroutine');
    $text   = defined $text ? "$text|" : '';

    return "L<$text$object>" if $object->isa('OODoc::Manual');

    my $manlink = defined $manual ? $object->manual.'/' : '';

      $object->isa('OODoc::Text::Structure') ? qq(L<$text$manlink"$object">)
    : confess "cannot link to a ".ref $object;
}


sub createManual($@)
{   my ($self, %args) = @_;
    my $verbose  = $args{verbose} || 0;
    my $manual   = $args{manual} or confess;
    my $options  = $args{format_options} || [];

    print $manual->orderedChapters." chapters in $manual\n" if $verbose>=3;
    my $podname  = $manual->source;
    $podname     =~ s/\.pm$/.pod/;
    my $tmpname  =  $podname . 't';

    my $tmpfile  = File::Spec->catfile($self->workdir, $tmpname);
    my $podfile  = File::Spec->catfile($self->workdir, $podname);

    my $output  = IO::File->new($tmpfile, "w")
        or die "ERROR: cannot write prelimary pod manual to $tmpfile: $!";

    $self->formatManual
      ( manual => $manual
      , output => $output
      , append => $args{append}
      , @$options
      );

    $output->close;

    $self->cleanupPOD($tmpfile, $podfile);
    unlink $tmpfile;

    $self->manifest->add($podfile);

    $self;
}


sub formatManual(@)
{   my $self = shift;
    $self->chapterName(@_);
    $self->chapterInheritance(@_);
    $self->chapterSynopsis(@_);
    $self->chapterDescription(@_);
    $self->chapterOverloaded(@_);
    $self->chapterMethods(@_);
    $self->chapterExports(@_);
    $self->chapterDetails(@_);
    $self->chapterDiagnostics(@_);
    $self->chapterReferences(@_);
    $self->chapterCopyrights(@_);
    $self->showAppend(@_);
    $self;
}

sub showAppend(@)
{   my ($self, %args) = @_;
    my $append = $args{append};

       if(!defined $append)      { ; }
    elsif(ref $append eq 'CODE') { $append->(formatter => $self, %args) }
    else
    {   my $output = $args{output} or confess;
        $output->print($append);
    }

    $self;
}

sub showStructureExpand(@)
{   my ($self, %args) = @_;

    my $examples = $args{show_chapter_examples} || 'EXPAND';
    my $text     = $args{structure} or confess;

    my $name     = $text->name;
    my $level    = $text->level;
    my $output   = $args{output}  or confess;
    my $manual   = $args{manual}  or confess;

    my $descr   = $self->cleanup($manual, $text->description);
    $output->print("\n=head$level $name\n\n$descr");

    $self->showSubroutines(%args, subroutines => [$text->subroutines]);
    $self->showExamples(%args, examples => [$text->examples])
         if $examples eq 'EXPAND';

    return $self;
}

sub showStructureRefer(@)
{   my ($self, %args) = @_;

    my $text     = $args{structure} or confess;

    my $name     = $text->name;
    my $level    = $text->level;
    my $output   = $args{output}  or confess;
    my $manual   = $args{manual}  or confess;

    my $link     = $self->link($manual, $text);
    $output->print("\n=head$level $name\n\nSee $link.\n");
    $self;
}

sub chapterDescription(@)
{   my ($self, %args) = @_;

    $self->showRequiredChapter(DESCRIPTION => %args);

    my $manual  = $args{manual} or confess;
    my $details = $manual->chapter('DETAILS');
   
    return $self unless defined $details;

    my $output  = $args{output} or confess;
    $output->print("\nSee L</DETAILS> chapter below\n");
    $self->showChapterIndex($output, $details, "   ");
}

sub chapterDiagnostics(@)
{   my ($self, %args) = @_;

    my $manual  = $args{manual} or confess;
    my $diags   = $manual->chapter('DIAGNOSTICS');

    $self->showChapter(chapter => $diags, %args)
        if defined $diags;

    my @diags   = map {$_->diagnostics} $manual->subroutines;
    return unless @diags;

    unless($diags)
    {   my $output = $args{output} or confess;
        $output->print("\n=head1 DIAGNOSTICS\n");
    }

    $self->showDiagnostics(%args, diagnostics => \@diags);
    $self;
}


sub showChapterIndex($$;$)
{   my ($self, $output, $chapter, $indent) = @_;
    $indent = '' unless defined $indent;

    foreach my $section ($chapter->sections)
    {   $output->print($indent, $section->name, "\n");
        foreach my $subsection ($section->subsections)
        {   $output->print($indent, $indent, $subsection->name, "\n");
        }
    }
    $self;
}

sub showExamples(@)
{   my ($self, %args) = @_;
    my $examples = $args{examples} or confess;
    return unless @$examples;

    my $manual    = $args{manual}  or confess;
    my $output    = $args{output}  or confess;

    foreach my $example (@$examples)
    {   my $name    = $self->cleanup($manual, $example->name);
        $output->print("\nexample: $name\n\n");
        $output->print($self->cleanup($manual, $example->description));
    }
    $self;
}

sub showDiagnostics(@)
{   my ($self, %args) = @_;
    my $diagnostics = $args{diagnostics} or confess;
    return unless @$diagnostics;

    my $manual    = $args{manual}  or confess;
    my $output    = $args{output}  or confess;

    foreach my $diag (sort @$diagnostics)
    {   my $name    = $self->cleanup($manual, $diag->name);
        my $type    = $diag->type;
        $output->print("\n$type: $name\n\n=over 4\n\n");
        $output->print($self->cleanup($manual, $diag->description));
        $output->print("\n\n=back\n\n");
    }
    $self;
}

sub showSubroutine(@)
{   my $self = shift;
    $self->SUPER::showSubroutine(@_);

    my %args   = @_;
    my $output = $args{output} or confess;
    $output->print("\n=back\n");
    $self;
}

sub showSubroutineUse(@)
{   my ($self, %args) = @_;
    my $subroutine = $args{subroutine} or confess;
    my $manual     = $args{manual}     or confess;
    my $output     = $args{output}     or confess;

    my $use        = $self->subroutineUse($manual, $subroutine);

    $output->print( qq[\n$use\n\n=over 4\n] );

    $output->print("\nSee ". $self->link($manual, $subroutine)."\n")
        if $manual->inherited($subroutine);

    $self;
}

sub subroutineUse($$)
{   my ($self, $manual, $subroutine) = @_;
    my $type       = $subroutine->type;
    my $name       = $self->cleanup($manual, $subroutine->name);
    my $paramlist  = $self->cleanup($manual, $subroutine->parameters);
    my $params     = length $paramlist ? "($paramlist)" : '';

    my $class      = $manual->package;
    my $use
     = $type eq 'i_method' ? qq[\$obj-E<gt>B<$name>$params]
     : $type eq 'c_method' ? qq[$class-E<gt>B<$name>$params]
     : $type eq 'ci_method'? qq[\$obj-E<gt>B<$name>$params\n\n]
                           . qq[$class-E<gt>B<$name>$params]
     : $type eq 'function' ? qq[B<$name>$params]
     : $type eq 'overload' ? qq[overload: B<$name>$params]
     : $type eq 'tie'      ? qq[B<$name>$params]
     :                       '';

    length $use
        or warn "WARNING: unknown subroutine type $type for $name in $manual";

    $use;
}

sub showSubroutineName(@)
{   my ($self, %args) = @_;
    my $subroutine = $args{subroutine} or confess;
    my $manual     = $args{manual}     or confess;
    my $output     = $args{output}     or confess;
    my $name       = $subroutine->name;

    my $url
     = $manual->inherited($subroutine)
     ? "M<".$subroutine->manual."::$name>"
     : "M<$name>";

    $output->print
     ( $self->cleanup($manual, $url)
     , ($args{last} ? ".\n" : ",\n")
     );
}

sub showOptionUse(@)
{   my ($self, %args) = @_;
    my $output = $args{output} or confess;
    my $option = $args{option} or confess;

    my $params = $option->parameters;
    $params    =~ s/\s+$//;
    $params    =~ s/^\s+//;
    $params    = " => $params" if length $params;
 
    $output->print("\n. $option$params\n");
    $self;
}

sub showOptionExpand(@)
{   my ($self, %args) = @_;
    my $output = $args{output} or confess;
    my $option = $args{option} or confess;
    my $manual = $args{manual}  or confess;

    $self->showOptionUse(%args);

    my $where = $option->findDescriptionObject or return $self;
    my $descr = $self->cleanup($manual, $where->description);
    $output->print("\n=over 4\n\n$descr\n=back\n")
       if length $descr;

    $self;
}


sub writeTable($@)
{   my ($self, %args) = @_;

    my $head   = $args{header} or confess;
    my $output = $args{output} or confess;
    my $rows   = $args{rows}   or confess;
    return unless @$rows;

    # Convert all elements to plain text, because markup is not
    # allowed in verbatim pod blocks.
    my @rows;
    foreach my $row (@$rows)
    {   push @rows, [ map {$self->removeMarkup($_)} @$row ];
    }

    # Compute column widths
    my @w      = (0) x @$head;

    foreach my $row ($head, @rows)
    {   $w[$_] = max $w[$_], length($row->[$_])
           foreach 0..$#$row;
    }

    if(my $widths = $args{widths})
    {   defined $widths->[$_] && ($w[$_] = $widths->[$_])
           foreach 0..$#$rows;
    }

    pop @w;   # ignore width of last column

    # Table head
    my $headf  = " ".join("--", map { "\%-${_}s" } @w)."--%s\n";
    $output->printf($headf, @$head);

    # Table body
    my $format = " ".join("  ", map { "\%-${_}s" } @w)."  %s\n";
    $output->printf($format, @$_)
       for @rows;
}


sub removeMarkup($)
{   my ($self, $string) = @_;
    my $out = $self->_removeMarkup($string);
    for($out)
    {   s/^\s+//gm;
        s/\s+$//gm;
        s/\s{2,}/ /g;
        s/\[NB\]/ /g;
    }
    $out;
}

sub _removeMarkup($)
{   my ($self, $string) = @_;

    my $out = '';
    while($string =~ s/(.*?)         # before
                       ([BCEFILSXZ]) # known formatting codes
                       ([<]+)        # capture ALL starters
                      //x)
    {   $out .= $1;
        my ($tag, $bracks, $brack_count) = ($2, $3, length($3));

        if($string !~ s/^(|.*?[^>])  # contained
                        [>]{$brack_count}
                        (?![>])
                       //xs)
        {   $out .= "$tag$bracks";
            next;
        }

        my $container = $1;
        if($tag =~ m/[XZ]/) { ; }  # ignore container content
        elsif($tag =~ m/[BCI]/)    # cannot display, but can be nested
        {   $out .= $self->_removeMarkup($container);
        }
        elsif($tag eq 'E') { $out .= e2char($container) }
        elsif($tag eq 'F') { $out .= $container }
        elsif($tag eq 'L')
        {   if($container =~ m!^\s*([^/|]*)\|!)
            {    $out .= $self->_removeMarkup($1);
                 next;
            }
   
            my ($man, $chapter) = ($container, '');
            if($container =~ m!^\s*([^/]*)/\"([^"]*)\"\s*$!)
            {   ($man, $chapter) = ($1, $2);
            }
            elsif($container =~ m!^\s*([^/]*)/(.*?)\s*$!)
            {   ($man, $chapter) = ($1, $2);
            }

            $out .=
             ( !length $man     ? "section $chapter"
             : !length $chapter ? $man
             :                    "$man section $chapter"
             );
        }
        elsif($tag eq 'S')
        {   my $clean = $self->_removeMarkup($container);
            $clean =~ s/ /[NB]/g;
            $out  .= $clean;
        }
    }

    $out . $string;
}

sub showSubroutineDescription(@)
{   my ($self, %args) = @_;
    my $manual  = $args{manual}                   or confess;
    my $subroutine = $args{subroutine}            or confess;

    my $text    = $self->cleanup($manual, $subroutine->description);
    return $self unless length $text;

    my $output  = $args{output}                   or confess;
    $output->print("\n", $text);

    my $extends = $self->extends                  or return $self;
    my $refer   = $extends->findDescriptionObject or return $self;
    $self->showSubroutineDescriptionRefer(%args, subroutine => $refer);
}

sub showSubroutineDescriptionRefer(@)
{   my ($self, %args) = @_;
    my $manual  = $args{manual}                   or confess;
    my $subroutine = $args{subroutine}            or confess;
    my $output  = $args{output}                   or confess;
    $output->print("\nSee ", $self->link($manual, $subroutine), "\n");
}

sub showSubsIndex() {;}


sub cleanupPOD($$)
{   my ($self, $infn, $outfn) = @_;
    my $in = IO::File->new($infn, 'r')
        or die "ERROR: cannot read prelimary pod from $infn: $!\n";

    my $out = IO::File->new($outfn, 'w')
        or die "ERROR: cannot write final pod to $outfn: $!\n";

    my $last_is_blank = 1;
  LINE:
    while(my $l = $in->getline)
    {   if($l =~ m/^\s*$/s)
        {   next LINE if $last_is_blank;
            $last_is_blank = 1;
        }
        else
        {   $last_is_blank = 0;
        }

        $out->print($l);
    }

    $in->close;
    $out->close
       or die "ERROR: write to $outfn failed: $!\n";

    $self;
}


1;
