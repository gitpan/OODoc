
package OODoc;
use vars '$VERSION';
$VERSION = '0.94';
use base 'OODoc::Object';

use strict;
use warnings;

use OODoc::Manifest;

use Carp;
use File::Copy;
use File::Spec;
use File::Basename;
use IO::File;
use List::Util 'first';


#-------------------------------------------


sub init($)
{   my ($self, $args) = @_;

    $self->SUPER::init($args) or return;

    $self->{O_pkg}    = {};

    my $distribution  = $self->{O_distribution} = delete $args->{distribution};
    croak "ERROR: the produced distribution needs a project description"
        unless defined $distribution;

    $self->{O_project} = delete $args->{project} || $distribution;

    my $version        = delete $args->{version};
    unless(defined $version)
    {   my $fn         = -f 'version' ? 'version'
                       : -f 'VERSION' ? 'VERSION'
                       : undef;
        if(defined $fn)
        {   my $v = IO::File->new($fn, 'r')
               or die "ERROR: Cannot read version from file $fn: $!\n";
            $version = $v->getline;
            $version = $1 if $version =~ m/(\d+\.[\d\.]+)/;
            chomp $version;
        }
    }

    croak "ERROR: no version specified for distribution \"$distribution\""
        unless defined $version;

    $self->{O_version} = $version;
    $self->{O_verbose} = delete $args->{verbose} || 0;
    $self;
}

#-------------------------------------------


sub distribution() {shift->{O_distribution}}

#-------------------------------------------


sub version() {shift->{O_version}}

#-------------------------------------------


sub project() {shift->{O_project}}

#-------------------------------------------


sub selectFiles($@)
{   my ($self, $files) = (shift, shift);

    my $select
      = ref $files eq 'Regexp' ? sub { $_[0] =~ $files }
      : ref $files eq 'CODE'   ? $files
      : ref $files eq 'ARRAY'  ? $files
      : croak "ERROR: use regex, code reference or array for file selection";

    return ($select, []) if ref $select eq 'ARRAY';

    my (@process, @copy);
    foreach my $fn (@_)
    {   if($select->($fn)) {push @process, $fn}
        else               {push @copy,    $fn}
    }

    ( \@process, \@copy );
}

#-------------------------------------------


sub processFiles(@)
{   my ($self, %args) = @_;
    my $verbose = defined $args{verbose} ? $args{verbose} : $self->{O_verbose};

    croak "ERROR: requires a directory to write the distribution to"
       unless exists $args{workdir};

    my $dest    = $args{workdir};
    my $source  = $args{source};
    my $distr   = $args{distribution} || $self->distribution;

    my $version = $args{version};
    unless(defined $version)
    {   my $fn  = defined $source ? File::Spec->catfile($source, 'version')
                :                   'version';
        $fn     = -f $fn          ? $fn
                : defined $source ? File::Spec->catfile($source, 'VERSION')
                :                   'VERSION';
        if(defined $fn)
        {   my $v = IO::File->new($fn, "r")
                or die "ERROR: Cannot read version from $fn: $!";
            $version = $v->getline;
            $version = $1 if $version =~ m/(\d+\.[\d\.]+)/;
            chomp $version;
        }
        elsif($version = $self->version) { ; }
        else
        {   die "ERROR: there is no version defined for the source files.\n";
        }
    }

    #
    # Split the set of files into those who do need special processing
    # and those who do not.
    #

    my $manfile
      = exists $args{manifest} ? $args{manifest}
      : defined $source        ? File::Spec->catfile($source, 'MANIFEST')
      :                          'MANIFEST';

    my $manifest = OODoc::Manifest->new(filename => $manfile);

    my $manout;
    if(defined $dest)
    {   my $manif = File::Spec->catfile($dest, 'MANIFEST');
        $manout   = OODoc::Manifest->new(filename => $manif);
        $manout->add($manif);
    }
    else
    {   $manout   = OODoc::Manifest->new(filename => undef);
    }

    my $select    = $args{select} || qr/\.(pm|pod)$/;
    my ($process, $copy) = $self->selectFiles($select, @$manifest);

    print @$process. " files to process and ".@$copy." files to copy\n"
       if $verbose > 1;

    #
    # Copy all the files which do not contain pseudo doc
    #

    if(defined $dest)
    {   foreach my $filename (@$copy)
        {   my $fn = defined $source ? File::Spec->catfile($source, $filename)
                   :                   $filename;

            my $dn = File::Spec->catfile($dest, $fn);
            carp "WARNING: no file $fn to include in the distribution", next
               unless -f $fn;

            unless(-e $dn && ( -M $dn < -M $fn ) && ( -s $dn == -s $fn ))
            {   $self->mkdirhier(dirname $dn);

                copy($fn, $dn)
                   or die "ERROR: cannot copy distribution file $fn to $dest: $!\n";

                print "Copied $fn to $dest\n" if $verbose > 2;
            }

            $manout->add($dn);
        }
    }

    #
    # Create the parser
    #

    my $parser = $args{parser} || 'OODoc::Parser::Markov';
    unless(ref $parser)
    {   eval "{require $parser}";
        croak "ERROR: Cannot compile $parser class:\n$@"
           if $@;

        $parser = $parser->new
           or croak "ERROR: Parser $parser could not be instantiated";
    }

    #
    # Now process the rest
    #

    foreach my $filename (@$process)
    {   my $fn = $source ? File::Spec->catfile($source, $filename) : $filename; 

        carp "WARNING: no file $fn to include in the distribution", next
            unless -f $fn;

        my $dn;
        if($dest)
        {   $dn = File::Spec->catfile($dest, $fn);
            $self->mkdirhier(dirname $dn);
            $manout->add($dn);
        }

        # do the stripping
        my @manuals = $parser->parse
          ( input        => $fn
          , output       => $dn
          , distribution => $distr
          , version      => $version
          );

        if($verbose > 2)
        {   print "Stripped $fn into $dn\n" if defined $dn;
            print $_->stats foreach @manuals;
        }

        foreach my $man (@manuals)
        {   $self->addManual($man) if $man->chapters;
        }
    }

    #
    # Some general subtotals
    #

    print $self->stats if $verbose > 1;
    $self;
}

#-------------------------------------------


sub prepare(@)
{   my ($self, %args) = @_;
    my $verbose = defined $args{verbose} ? $args{verbose} : $self->{O_verbose};

    print "Collect package relations.\n" if $verbose >1;
    $self->getPackageRelations;

    print "Expand manual contents.\n" if $verbose >1;
    $self->expandManuals;

    $self;
}

#-------------------------------------------


sub getPackageRelations()
{   my $self     = shift;
    my @manuals  = $self->manuals;  # all

    #
    # load all distributions (which are not loaded yet)
    #

    foreach my $manual (@manuals)
    {    next if $manual->isPurePod;
         eval "require $manual";
         if($@ && $@ !~ /Can't locate/)
         {   die "$@";
         }
    }

    foreach my $manual (@manuals)
    {
        if($manual->name ne $manual->package)  # autoloaded code
        {   my $main = $self->mainManual("$manual");
            $main->extraCode($manual) if defined $main;
            next;
        }
        my %uses = $manual->collectPackageRelations;

        foreach (defined $uses{isa} ? @{$uses{isa}} : ())
        {   my $isa = $self->mainManual($_) || $_;

            $manual->superClasses($isa);
            $isa->subClasses($manual) if ref $isa;
        }

        if(my $realizes = $uses{realizes})
        {   my $to  = $self->mainManual($realizes) || $realizes;

            $manual->realizes($to);
            $to->realizers($manual) if ref $to;
        }
    }

    $self;
}

#-------------------------------------------


sub expandManuals() { $_->expand foreach shift->manuals }

#-------------------------------------------


our %formatters =
 ( pod  => 'OODoc::Format::Pod'
 , pod2 => 'OODoc::Format::Pod2'
 , html => 'OODoc::Format::Html'
 );

sub create($@)
{   my ($self, $format, %args) = @_;
    my $verbose = defined $args{verbose} ? $args{verbose} : $self->{O_verbose};

    my $dest    = $args{workdir}
       or croak "ERROR: requires a directory to write the manuals to";

    #
    # Start manifest
    #

    my $manfile  = exists $args{manifest} ? $args{manifest}
                 : File::Spec->catfile($dest, 'MANIFEST');
    my $manifest = OODoc::Manifest->new(filename => $manfile);

    # Create the formatter

    unless(ref $format)
    {   $format = $formatters{$format} if exists $formatters{$format};

        eval "require $format";
        die "ERROR: formatter $format has compilation errors: $@" if $@;

        my $options    = delete $args{format_options} || [];

        $format = $format->new
          ( manifest    => $manifest
          , workdir     => $dest
          , project     => $self->distribution
          , version     => $self->version
          , @$options
          );
    }

    #
    # Create the manual pages
    #

    my $select = ! defined $args{select}     ? sub {1}
               : ref $args{select} eq 'CODE' ? $args{select}
               :                        sub { $_[0]->name =~ $args{select}};

    foreach my $package (sort $self->packageNames)
    {
        foreach my $manual ($self->manualsForPackage($package))
        {   next unless $select->($manual);

            unless($manual->chapters)
            {   print "Skipping $manual: no chapters\n" if $verbose > 1;
                next;
            }

            print "Creating manual $manual with ",ref($format), "\n"
                if $verbose > 1;

            $format->createManual
             ( manual         => $manual
             , template       => $args{manual_template}
             , append         => $args{append}
             , format_options => ($args{manual_format} || [])
             );
        }
    }

    #
    # Create other pages
    #

    print "Creating other pages\n" if $verbose > 1;
    $format->createOtherPages
     ( source   => $args{other_files}
     , process  => $args{process_files}
     );

    $format;
}

#-------------------------------------------


sub stats()
{   my $self = shift;
    my @manuals  = $self->manuals;
    my $manuals  = @manuals;
    my $realpkg  = $self->packageNames;

    my $subs     = map {$_->subroutines} @manuals;
    my $examples = map {$_->examples}    @manuals;

    my $diags    = map {$_->diagnostics} @manuals;
    my $distribution   = $self->distribution;
    my $version  = $self->version;

    <<STATS;
$distribution version $version
  Number of package manuals: $manuals
  Real number of packages:   $realpkg
  documented subroutines:    $subs
  documented diagnostics:    $diags
  shown examples:            $examples
STATS
}

#-------------------------------------------


1;
