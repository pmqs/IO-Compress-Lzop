package IO::Compress::Lzop ;

use strict ;
use warnings;
require Exporter ;
use bytes;

use IO::Compress::Base 2.214 ;

use IO::Compress::Base::Common  2.214 qw(isaScalar createSelfTiedObject);
use IO::Compress::Adapter::LZO  2.214 ;
use Compress::LZO qw(crc32 adler32 LZO_VERSION);
use IO::Compress::Lzop::Constants  2.214 ;

our ($VERSION, @ISA, @EXPORT_OK, %EXPORT_TAGS, $LzopError);

$VERSION = '2.214';
$LzopError = '';

@ISA    = qw( IO::Compress::Base Exporter );
@EXPORT_OK = qw( $LzopError lzop ) ;
%EXPORT_TAGS = %IO::Compress::Base::EXPORT_TAGS ;
$EXPORT_TAGS{all} = [ defined $EXPORT_TAGS{all} ? @{ $EXPORT_TAGS{all} } : (), @EXPORT_OK ] ;
Exporter::export_ok_tags('all');

sub new
{
    my $class = shift ;

    my $obj = createSelfTiedObject($class, \$LzopError);
    return $obj->_create(undef, @_);
}

sub lzop
{
    my $obj = createSelfTiedObject(undef, \$LzopError);
    return $obj->_def(@_);
}

#sub ckSum
#{
#    my $self = shift ;
#
#    return adler32($_[0]) if *$self->{LZOP}{Adler32} ;
#    return crc32($_[0]) if *$self->{LZOP}{CRRC32} ;
#    return '';
#}

sub mkHeader
{
    my $self = shift ;
    my $param = shift ;

    my $filename = '';

    my $time = $param->getValue('time') ;

    my $flags = F_OS_UNIX  ;
    if (! $param->getValue('minimal')) {
        $flags |= F_ADLER32_D | F_ADLER32_C ;
        $filename = $param->getValue('name') || '';
    }

    my $mode = 0 ;
    if ($param->getValue('mode')) {
        $mode = $param->getValue('mode');
    }

    my $xtr = '';
    if ($param->parsed('extra')) {
        $flags |= F_H_EXTRA_FIELD ;

        my $extra = $param->getValue('extra') ;
        $xtr .= pack 'N', length($extra)  ; # Extra Length
        $xtr .= $extra                    ; # Extra Data
        $xtr .= pack 'N', adler32($xtr)   ; # Extra CRC
    }

    my $hdr = '' ;

    $hdr .= pack 'n', 0x1010     ; # lzop Version
    $hdr .= pack 'n', 0x1080     ; # LZO library version
    $hdr .= pack 'n', 0x1010     ; # lzop extract version
    $hdr .= pack 'C', 1          ; # Method
    $hdr .= pack 'C', 5          ; # Level
    $hdr .= pack 'N', $flags     ; # Flags

    $hdr .= pack 'N', $mode      ; # Mode
    $hdr .= pack 'N', $time      ; # Time
    $hdr .= pack 'N', 0          ; # GMDiff

    # Filename
    $hdr .= pack 'C', length $filename ; # filename length
    $hdr .= $filename ;

    # Header CRC
    $hdr .= pack 'N', adler32($hdr) ; # Header CRC

    # Extra
    $hdr .= $xtr;

    return SIGNATURE . $hdr;

}

sub ckParams
{
    my $self = shift ;
    my $got = shift;

    if (! $got->parsed('time') ) {
        # Modification time defaults to now.
        $got->setValue('time' => time) ;
    }

    #*$self->{LZOP}{Adler32} = ($got->getValue('??') ? 0 : 1) ;

    return 1 ;
}


sub mkComp
{
    my $self = shift ;
    my $got = shift ;

    my ($obj, $errstr, $errno) =  IO::Compress::Adapter::LZO::mkCompObject(
                                              $got->getValue('blocksize'),
                                              $got->getValue('optimize'),
                                              $got->getValue('minimal'),
                                          );

    return $self->saveErrorString(undef, $errstr, $errno)
        if ! defined $obj;

    return $obj;

}


sub mkTrailer
{
    my $self = shift ;
    return pack "N", 0 ;
}

sub mkFinalTrailer
{
    return '';
}

#sub newHeader
#{
#    my $self = shift ;
#    return '';
#}

our %PARAMS = (
    'name'      => [IO::Compress::Base::Common::Parse_any,       undef],
    'time'      => [IO::Compress::Base::Common::Parse_any,       undef],
    'mode'      => [IO::Compress::Base::Common::Parse_any,       0],
    'extra'     => [IO::Compress::Base::Common::Parse_any,       undef],
    'minimal'   => [IO::Compress::Base::Common::Parse_boolean,   0],
    'blocksize' => [IO::Compress::Base::Common::Parse_unsigned,  BLOCK_SIZE],
    'optimize'  => [IO::Compress::Base::Common::Parse_boolean,   1],

   # TODO
   #   none
   #   crc32
   #   adler32
       );

sub getExtraParams
{
    return %PARAMS ;
}

sub getInverseClass
{
    return ('IO::Uncompress::UnLzop');
}

sub getFileInfo
{
    my $self = shift ;
    my $params = shift;
    my $filename = shift ;

    return
      if isaScalar($filename) ;

    my ($defaultMode, $defaultTime) = (stat($filename))[2, 9] ;

    $params->setValue('name' => $filename)
        if ! $params->parsed('name') ;

    $params->setValue('time' => $defaultTime)
        if ! $params->parsed('time') ;

    $params->setValue('mode' => $defaultMode)
        if ! $params->parsed('mode') ;
}

1;

__END__

=head1 NAME

IO::Compress::Lzop - Write lzop files/buffers

=head1 SYNOPSIS

    use IO::Compress::Lzop qw(lzop $LzopError) ;

    my $status = lzop $input => $output [,OPTS]
        or die "lzop failed: $LzopError\n";

    my $z = IO::Compress::Lzop->new( $output [,OPTS] )
        or die "lzop failed: $LzopError\n";

    $z->print($string);
    $z->printf($format, $string);
    $z->write($string);
    $z->syswrite($string [, $length, $offset]);
    $z->flush();
    $z->tell();
    $z->eof();
    $z->seek($position, $whence);
    $z->binmode();
    $z->fileno();
    $z->opened();
    $z->autoflush();
    $z->input_line_number();
    $z->newStream( [OPTS] );

    $z->close() ;

    $LzopError ;

    # IO::File mode

    print $z $string;
    printf $z $format, $string;
    tell $z
    eof $z
    seek $z, $position, $whence
    binmode $z
    fileno $z
    close $z ;

=head1 DESCRIPTION

This module provides a Perl interface that allows writing lzop
compressed data to files or buffer.

For reading lzop files/buffers, see the companion module
L<IO::Uncompress::UnLzop|IO::Uncompress::UnLzop>.

=head1 Functional Interface

A top-level function, C<lzop>, is provided to carry out
"one-shot" compression between buffers and/or files. For finer
control over the compression process, see the L</"OO Interface">
section.

    use IO::Compress::Lzop qw(lzop $LzopError) ;

    lzop $input_filename_or_reference => $output_filename_or_reference [,OPTS]
        or die "lzop failed: $LzopError\n";

The functional interface needs Perl5.005 or better.

=head2 lzop $input_filename_or_reference => $output_filename_or_reference [, OPTS]

C<lzop> expects at least two parameters,
C<$input_filename_or_reference> and C<$output_filename_or_reference>
and zero or more optional parameters (see L</Optional Parameters>)

=head3 The C<$input_filename_or_reference> parameter

The parameter, C<$input_filename_or_reference>, is used to define the
source of the uncompressed data.

It can take one of the following forms:

=over 5

=item A filename

If the C<$input_filename_or_reference> parameter is a simple scalar, it is
assumed to be a filename. This file will be opened for reading and the
input data will be read from it.

=item A filehandle

If the C<$input_filename_or_reference> parameter is a filehandle, the input
data will be read from it.  The string '-' can be used as an alias for
standard input.

=item A scalar reference

If C<$input_filename_or_reference> is a scalar reference, the input data
will be read from C<$$input_filename_or_reference>.

=item An array reference

If C<$input_filename_or_reference> is an array reference, each element in
the array must be a filename.

The input data will be read from each file in turn.

The complete array will be walked to ensure that it only
contains valid filenames before any data is compressed.

=item An Input FileGlob string

If C<$input_filename_or_reference> is a string that is delimited by the
characters "<" and ">" C<lzop> will assume that it is an
I<input fileglob string>. The input is the list of files that match the
fileglob.

See L<File::GlobMapper|File::GlobMapper> for more details.

=back

If the C<$input_filename_or_reference> parameter is any other type,
C<undef> will be returned.

In addition, if C<$input_filename_or_reference> is a simple filename,
the default values for
the C<Name> and C<Time> options will be sourced from that file.

If you do not want to use these defaults they can be overridden by
explicitly setting the C<Name> and C<Time> options or by setting the
C<Minimal> parameter.

=head3 The C<$output_filename_or_reference> parameter

The parameter C<$output_filename_or_reference> is used to control the
destination of the compressed data. This parameter can take one of
these forms.

=over 5

=item A filename

If the C<$output_filename_or_reference> parameter is a simple scalar, it is
assumed to be a filename.  This file will be opened for writing and the
compressed data will be written to it.

=item A filehandle

If the C<$output_filename_or_reference> parameter is a filehandle, the
compressed data will be written to it.  The string '-' can be used as
an alias for standard output.

=item A scalar reference

If C<$output_filename_or_reference> is a scalar reference, the
compressed data will be stored in C<$$output_filename_or_reference>.

=item An Array Reference

If C<$output_filename_or_reference> is an array reference,
the compressed data will be pushed onto the array.

=item An Output FileGlob

If C<$output_filename_or_reference> is a string that is delimited by the
characters "<" and ">" C<lzop> will assume that it is an
I<output fileglob string>. The output is the list of files that match the
fileglob.

When C<$output_filename_or_reference> is an fileglob string,
C<$input_filename_or_reference> must also be a fileglob string. Anything
else is an error.

See L<File::GlobMapper|File::GlobMapper> for more details.

=back

If the C<$output_filename_or_reference> parameter is any other type,
C<undef> will be returned.

=head2 Notes

When C<$input_filename_or_reference> maps to multiple files/buffers and
C<$output_filename_or_reference> is a single
file/buffer the input files/buffers will each be stored
in C<$output_filename_or_reference> as a distinct entry.

=head2 Optional Parameters

The optional parameters for the one-shot function C<lzop>
are (for the most part) identical to those used with the OO interface defined in the
L</"Constructor Options"> section. The exceptions are listed below

=over 5

=item C<< AutoClose => 0|1 >>

This option applies to any input or output data streams to
C<lzop> that are filehandles.

If C<AutoClose> is specified, and the value is true, it will result in all
input and/or output filehandles being closed once C<lzop> has
completed.

This parameter defaults to 0.

=item C<< BinModeIn => 0|1 >>

This option is now a no-op. All files will be read in binmode.

=item C<< Append => 0|1 >>

The behaviour of this option is dependent on the type of output data
stream.

=over 5

=item * A Buffer

If C<Append> is enabled, all compressed data will be append to the end of
the output buffer. Otherwise the output buffer will be cleared before any
compressed data is written to it.

=item * A Filename

If C<Append> is enabled, the file will be opened in append mode. Otherwise
the contents of the file, if any, will be truncated before any compressed
data is written to it.

=item * A Filehandle

If C<Append> is enabled, the filehandle will be positioned to the end of
the file via a call to C<seek> before any compressed data is
written to it.  Otherwise the file pointer will not be moved.

=back

When C<Append> is specified, and set to true, it will I<append> all compressed
data to the output data stream.

So when the output is a filehandle it will carry out a seek to the eof
before writing any compressed data. If the output is a filename, it will be opened for
appending. If the output is a buffer, all compressed data will be
appended to the existing buffer.

Conversely when C<Append> is not specified, or it is present and is set to
false, it will operate as follows.

When the output is a filename, it will truncate the contents of the file
before writing any compressed data. If the output is a filehandle
its position will not be changed. If the output is a buffer, it will be
wiped before any compressed data is output.

Defaults to 0.

=back

=head2 Oneshot Examples

Here are a few example that show the capabilities of the module.

=head3 Streaming

This very simple command line example demonstrates the streaming capabilities of the module.
The code reads data from STDIN, compresses it, and writes the compressed data to STDOUT.

    $ echo hello world | perl -MIO::Compress::Lzop=lzop -e 'lzop \*STDIN => \*STDOUT' >output.lzo

The special filename "-" can be used as a standin for both C<\*STDIN> and C<\*STDOUT>,
so the above can be rewritten as

    $ echo hello world | perl -MIO::Compress::Lzop=lzop -e 'lzop "-" => "-"' >output.lzo

=head3 Compressing a file from the filesystem

To read the contents of the file C<file1.txt> and write the compressed
data to the file C<file1.txt.lzo>.

    use strict ;
    use warnings ;
    use IO::Compress::Lzop qw(lzop $LzopError) ;

    my $input = "file1.txt";
    lzop $input => "$input.lzo"
        or die "lzop failed: $LzopError\n";

=head3 Reading from a Filehandle and writing to an in-memory buffer

To read from an existing Perl filehandle, C<$input>, and write the
compressed data to a buffer, C<$buffer>.

    use strict ;
    use warnings ;
    use IO::Compress::Lzop qw(lzop $LzopError) ;
    use IO::File ;

    my $input = IO::File->new( "<file1.txt" )
        or die "Cannot open 'file1.txt': $!\n" ;
    my $buffer ;
    lzop $input => \$buffer
        or die "lzop failed: $LzopError\n";

=head3 Compressing multiple files

To compress all files in the directory "/my/home" that match "*.txt"
and store the compressed data in the same directory

    use strict ;
    use warnings ;
    use IO::Compress::Lzop qw(lzop $LzopError) ;

    lzop '</my/home/*.txt>' => '<*.lzo>'
        or die "lzop failed: $LzopError\n";

and if you want to compress each file one at a time, this will do the trick

    use strict ;
    use warnings ;
    use IO::Compress::Lzop qw(lzop $LzopError) ;

    for my $input ( glob "/my/home/*.txt" )
    {
        my $output = "$input.lzo" ;
        lzop $input => $output
            or die "Error compressing '$input': $LzopError\n";
    }

=head1 OO Interface

=head2 Constructor

The format of the constructor for C<IO::Compress::Lzop> is shown below

    my $z = IO::Compress::Lzop->new( $output [,OPTS] )
        or die "IO::Compress::Lzop failed: $LzopError\n";

The constructor takes one mandatory parameter, C<$output>, defined below and
zero or more C<OPTS>, defined in L<Constructor Options>.

It returns an C<IO::Compress::Lzop> object on success and C<undef> on failure.
The variable C<$LzopError> will contain an error message on failure.

If you are running Perl 5.005 or better the object, C<$z>, returned from
IO::Compress::Lzop can be used exactly like an L<IO::File|IO::File> filehandle.
This means that all normal output file operations can be carried out
with C<$z>.
For example, to write to a compressed file/buffer you can use either of
these forms

    $z->print("hello world\n");
    print $z "hello world\n";

Below is a simple exaple of using the OO interface to create an output file
C<myfile.lzo> and write some data to it.

    my $filename = "myfile.lzo";
    my $z = IO::Compress::Lzop->new($filename)
        or die "IO::Compress::Lzop failed: $LzopError\n";

    $z->print("abcde");
    $z->close();

See the L</Examples> for more.

The mandatory parameter C<$output> is used to control the destination
of the compressed data. This parameter can take one of these forms.

=over 5

=item A filename

If the C<$output> parameter is a simple scalar, it is assumed to be a
filename. This file will be opened for writing and the compressed data
will be written to it.

=item A filehandle

If the C<$output> parameter is a filehandle, the compressed data will be
written to it.
The string '-' can be used as an alias for standard output.

=item A scalar reference

If C<$output> is a scalar reference, the compressed data will be stored
in C<$$output>.

=back

If the C<$output> parameter is any other type, C<IO::Compress::Lzop>::new will
return undef.

=head2 Constructor Options

C<OPTS> is any combination of zero or more the following options:

=over 5

=item C<< AutoClose => 0|1 >>

This option is only valid when the C<$output> parameter is a filehandle. If
specified, and the value is true, it will result in the C<$output> being
closed once either the C<close> method is called or the C<IO::Compress::Lzop>
object is destroyed.

This parameter defaults to 0.

=item C<< Append => 0|1 >>

Opens C<$output> in append mode.

The behaviour of this option is dependent on the type of C<$output>.

=over 5

=item * A Buffer

If C<$output> is a buffer and C<Append> is enabled, all compressed data
will be append to the end of C<$output>. Otherwise C<$output> will be
cleared before any data is written to it.

=item * A Filename

If C<$output> is a filename and C<Append> is enabled, the file will be
opened in append mode. Otherwise the contents of the file, if any, will be
truncated before any compressed data is written to it.

=item * A Filehandle

If C<$output> is a filehandle, the file pointer will be positioned to the
end of the file via a call to C<seek> before any compressed data is written
to it.  Otherwise the file pointer will not be moved.

=back

This parameter defaults to 0.

=item C<< Name => $string >>

Stores the contents of C<$string> in the name field lzop header.

If C<Name> is not specified, no gzip NAME field will be created.

=item C<< Time => $number >>

Sets the Time field in the lzop header to $number.

This field defaults to the time the C<IO::Compress::Lzop> object was created
if this option is not specified.

=item Extra

TODO

=item BlockSize

TODO

=item Optimize

TODO

=item Minimal

Creates the smallest possible lzop file/buffer.

Disables the creation of all checksums.

No Name is stored.

TODO

=item C<< Strict => 0|1 >>

This is a placeholder option.

=back

=head2 Examples

=head3 Streaming

This very simple command line example demonstrates the streaming capabilities
of the module. The code reads data from STDIN or all the files given on the
commandline, compresses it, and writes the compressed data to STDOUT.

    use strict ;
    use warnings ;
    use IO::Compress::Lzop qw(lzop $LzopError) ;

    my $z = IO::Compress::Lzop->new("-", Stream => 1)
        or die "IO::Compress::Lzop failed: $LzopError\n";

    while (<>) {
        $z->print("abcde");
    }
    $z->close();

Note the use of C<"-"> to means C<STDOUT>. Alternatively you can use C<\*STDOUT>.

=head3 Compressing a file from the filesystem

To read the contents of the file C<file1.txt> and write the compressed
data to the file C<file1.txt.lzo> there are a few options

Start by creating the compression object and opening the input file

    use strict ;
    use warnings ;
    use IO::Compress::Lzop qw(lzop $LzopError) ;

    my $input = "file1.txt";
    my $z = IO::Compress::Lzop->new("file1.txt.lzo")
        or die "IO::Compress::Lzop failed: $LzopError\n";

    # open the input file
    open my $fh, "<", "file1.txt"
        or die "Cannot open file1.txt: $!\n";

    # loop through the input file & write to the compressed file
    while (<$fh>) {
        $z->print($_);
    }

    # not forgetting to close the compressed file
    $z->close();

=head1 Methods

=head2 print

Usage is

    $z->print($data)
    print $z $data

Compresses and outputs the contents of the C<$data> parameter. This
has the same behaviour as the C<print> built-in.

Returns true if successful.

=head2 printf

Usage is

    $z->printf($format, $data)
    printf $z $format, $data

Compresses and outputs the contents of the C<$data> parameter.

Returns true if successful.

=head2 syswrite

Usage is

    $z->syswrite $data
    $z->syswrite $data, $length
    $z->syswrite $data, $length, $offset

Compresses and outputs the contents of the C<$data> parameter.

Returns the number of uncompressed bytes written, or C<undef> if
unsuccessful.

=head2 write

Usage is

    $z->write $data
    $z->write $data, $length
    $z->write $data, $length, $offset

Compresses and outputs the contents of the C<$data> parameter.

Returns the number of uncompressed bytes written, or C<undef> if
unsuccessful.

=head2 flush

Usage is

    $z->flush;

Flushes any pending compressed data to the output file/buffer.

TODO

Returns true on success.

=head2 tell

Usage is

    $z->tell()
    tell $z

Returns the uncompressed file offset.

=head2 eof

Usage is

    $z->eof();
    eof($z);

Returns true if the C<close> method has been called.

=head2 seek

    $z->seek($position, $whence);
    seek($z, $position, $whence);

Provides a sub-set of the C<seek> functionality, with the restriction
that it is only legal to seek forward in the output file/buffer.
It is a fatal error to attempt to seek backward.

Empty parts of the file/buffer will have NULL (0x00) bytes written to them.

The C<$whence> parameter takes one the usual values, namely SEEK_SET,
SEEK_CUR or SEEK_END.

Returns 1 on success, 0 on failure.

=head2 binmode

Usage is

    $z->binmode
    binmode $z ;

This is a noop provided for completeness.

=head2 opened

    $z->opened()

Returns true if the object currently refers to a opened file/buffer.

=head2 autoflush

    my $prev = $z->autoflush()
    my $prev = $z->autoflush(EXPR)

If the C<$z> object is associated with a file or a filehandle, this method
returns the current autoflush setting for the underlying filehandle. If
C<EXPR> is present, and is non-zero, it will enable flushing after every
write/print operation.

If C<$z> is associated with a buffer, this method has no effect and always
returns C<undef>.

B<Note> that the special variable C<$|> B<cannot> be used to set or
retrieve the autoflush setting.

=head2 input_line_number

    $z->input_line_number()
    $z->input_line_number(EXPR)

This method always returns C<undef> when compressing.

=head2 fileno

    $z->fileno()
    fileno($z)

If the C<$z> object is associated with a file or a filehandle, C<fileno>
will return the underlying file descriptor. Once the C<close> method is
called C<fileno> will return C<undef>.

If the C<$z> object is associated with a buffer, this method will return
C<undef>.

=head2 close

    $z->close() ;
    close $z ;

Flushes any pending compressed data and then closes the output file/buffer.

For most versions of Perl this method will be automatically invoked if
the IO::Compress::Lzop object is destroyed (either explicitly or by the
variable with the reference to the object going out of scope). The
exceptions are Perl versions 5.005 through 5.00504 and 5.8.0. In
these cases, the C<close> method will be called automatically, but
not until global destruction of all live objects when the program is
terminating.

Therefore, if you want your scripts to be able to run on all versions
of Perl, you should call C<close> explicitly and not rely on automatic
closing.

Returns true on success, otherwise 0.

If the C<AutoClose> option has been enabled when the IO::Compress::Lzop
object was created, and the object is associated with a file, the
underlying file will also be closed.

=head2 newStream([OPTS])

Usage is

    $z->newStream( [OPTS] )

Closes the current compressed data stream and starts a new one.

OPTS consists of any of the options that are available when creating
the C<$z> object.

See the L</"Constructor Options"> section for more details.

=head1 Importing

No symbolic constants are required by IO::Compress::Lzop at present.

=over 5

=item :all

Imports C<lzop> and C<$LzopError>.
Same as doing this

    use IO::Compress::Lzop qw(lzop $LzopError) ;

=back

=head1 EXAMPLES

=head1 SUPPORT

General feedback/questions/bug reports should be sent to
L<https://github.com/pmqs/IO-Compress-Lzop/issues> (preferred) or
L<https://rt.cpan.org/Public/Dist/Display.html?Name=IO-Compress-Lzop>.

=head1 SEE ALSO

L<Compress::Zlib>, L<IO::Compress::Gzip>, L<IO::Uncompress::Gunzip>, L<IO::Compress::Deflate>, L<IO::Uncompress::Inflate>, L<IO::Compress::RawDeflate>, L<IO::Uncompress::RawInflate>, L<IO::Compress::Bzip2>, L<IO::Uncompress::Bunzip2>, L<IO::Compress::Lzma>, L<IO::Uncompress::UnLzma>, L<IO::Compress::Xz>, L<IO::Uncompress::UnXz>, L<IO::Compress::Lzip>, L<IO::Uncompress::UnLzip>, L<IO::Uncompress::UnLzop>, L<IO::Compress::Lzf>, L<IO::Uncompress::UnLzf>, L<IO::Compress::Zstd>, L<IO::Uncompress::UnZstd>, L<IO::Uncompress::AnyInflate>, L<IO::Uncompress::AnyUncompress>

L<IO::Compress::FAQ|IO::Compress::FAQ>

L<File::GlobMapper|File::GlobMapper>, L<Archive::Zip|Archive::Zip>,
L<Archive::Tar|Archive::Tar>,
L<IO::Zlib|IO::Zlib>

=head1 AUTHOR

This module was written by Paul Marquess, C<pmqs@cpan.org>.

=head1 MODIFICATION HISTORY

See the Changes file.

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2005-2025 Paul Marquess. All rights reserved.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.
