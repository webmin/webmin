=head1 web-lib-funcs.pl

Common functions for Webmin CGI scripts. This file gets in-directly included
by all scripts that use web-lib.pl.
Example code:

  use WebminCore;
  init_config();
  ui_print_header(undef, 'My Module', '');
  print 'This is Webmin version ',get_webmin_version(),'<p>\n';
  ui_print_footer();

=cut

##use warnings;
use Socket;
use POSIX;
eval "use Socket6";
$ipv6_module_error = $@;
our $error_handler_funcs = [ ];

use vars qw($user_risk_level $loaded_theme_library $wait_for_input
	    $done_webmin_header $trust_unknown_referers $unsafe_index_cgi
	    %done_foreign_require $webmin_feedback_address
	    $user_skill_level $pragma_no_cache $foreign_args);
# Globals
use vars qw($module_index_name $number_to_month_map $month_to_number_map
	    $umask_already $default_charset $licence_status $os_type
	    $licence_message $script_name $loaded_theme_oo_library
	    $done_web_lib_funcs $os_version $module_index_link
	    $called_from_webmin_core $ipv6_module_error);

=head2 read_file(file, &hash, [&order], [lowercase], [split-char])

Fill the given hash reference with name=value pairs from a file. The required
parameters are :

=item file - The file to head, which must be text with each line like name=value

=item hash - The hash reference to add values read from the file to.

=item order - If given, an array reference to add names to in the order they were read

=item lowercase - If set to 1, names are converted to lower case

=item split-char - If set, names and values are split on this character instead of =

=cut
sub read_file
{
local $_;
my $split = defined($_[4]) ? $_[4] : "=";
my $realfile = &translate_filename($_[0]);
&open_readfile(ARFILE, $_[0]) || return 0;
while(<ARFILE>) {
	chomp;
	my $hash = index($_, "#");
	my $eq = index($_, $split);
	if ($hash != 0 && $eq >= 0) {
		my $n = substr($_, 0, $eq);
		my $v = substr($_, $eq+1);
		chomp($v);
		$_[1]->{$_[3] ? lc($n) : $n} = $v;
		push(@{$_[2]}, $n) if ($_[2]);
        	}
        }
close(ARFILE);
$main::read_file_missing{$realfile} = 0;	# It exists now
if (defined($main::read_file_cache{$realfile})) {
	%{$main::read_file_cache{$realfile}} = %{$_[1]};
	}
return 1;
}

=head2 read_file_cached(file, &hash, [&order], [lowercase], [split-char])

Like read_file, but reads from an in-memory cache if the file has already been
read in this Webmin script. Recommended, as it behaves exactly the same as
read_file, but can be much faster.

=cut
sub read_file_cached
{
my $realfile = &translate_filename($_[0]);
if (defined($main::read_file_cache{$realfile})) {
	# Use cached data
	%{$_[1]} = ( %{$_[1]}, %{$main::read_file_cache{$realfile}} );
	return 1;
	}
elsif ($main::read_file_missing{$realfile}) {
	# Doesn't exist, so don't re-try read
	return 0;
	}
else {
	# Actually read the file
	my %d;
	if (&read_file($_[0], \%d, $_[2], $_[3], $_[4])) {
		%{$main::read_file_cache{$realfile}} = %d;
		%{$_[1]} = ( %{$_[1]}, %d );
		return 1;
		}
	else {
		# Flag as non-existant
		$main::read_file_missing{$realfile} = 1;
		return 0;
		}
	}
}

=head2 read_file_cached_with_stat(file, &hash, [&order], [lowercase], [split-char])

Like read_file, but reads from an in-memory cache if the file has already been
read in this Webmin script AND has not changed.

=cut
sub read_file_cached_with_stat
{
my $realfile = &translate_filename($_[0]);
my $t = $main::read_file_cache_time{$realfile};
my @st = stat($realfile);
if ($t && $st[9] != $t) {
	# Changed, invalidate cache
	delete($main::read_file_cache{$realfile});
	}
my $rv = &read_file_cached(@_);
$main::read_file_cache_time{$realfile} = $st[9];
return $rv;
}

=head2 write_file(file, &hash, [join-char])

Write out the contents of a hash as name=value lines. The parameters are :

=item file - Full path to write to

=item hash - A hash reference containing names and values to output

=item join-char - If given, names and values are separated by this instead of =

=cut
sub write_file
{
my (%old, @order);
my $join = defined($_[2]) ? $_[2] : "=";
my $realfile = &translate_filename($_[0]);
&read_file($_[0], \%old, \@order);
&open_tempfile(ARFILE, ">$_[0]");
foreach $k (@order) {
	if (exists($_[1]->{$k})) {
		(print ARFILE $k,$join,$_[1]->{$k},"\n") ||
			&error(&text("efilewrite", $realfile, $!));
		}
	}
foreach $k (keys %{$_[1]}) {
	if (!exists($old{$k})) {
		(print ARFILE $k,$join,$_[1]->{$k},"\n") ||
			&error(&text("efilewrite", $realfile, $!));
		}
        }
&close_tempfile(ARFILE);
if (defined($main::read_file_cache{$realfile})) {
	%{$main::read_file_cache{$realfile}} = %{$_[1]};
	}
if (defined($main::read_file_missing{$realfile})) {
	$main::read_file_missing{$realfile} = 0;
	}
}

=head2 html_escape(string)

Converts &, < and > codes in text to HTML entities, and returns the new string.
This should be used when including data read from other sources in HTML pages.

=cut
sub html_escape
{
my ($tmp) = @_;
if (!defined $tmp) {
    return ''; # empty string
};
$tmp =~ s/&/&amp;/g;
$tmp =~ s/</&lt;/g;
$tmp =~ s/>/&gt;/g;
$tmp =~ s/\"/&quot;/g;
$tmp =~ s/\'/&#39;/g;
$tmp =~ s/=/&#61;/g;
return $tmp;
}

=head2 quote_escape(string, [only-quote])

Converts ' and " characters in a string into HTML entities, and returns it.
Useful for outputing HTML tag values.

=cut
sub quote_escape
{
my ($tmp, $only) = @_;
if (!defined $tmp) {
    return ''; # empty string
};
if ($tmp !~ /\&[a-zA-Z]+;/ && $tmp !~ /\&#/) {
	# convert &, unless it is part of &#nnn; or &foo;
	$tmp =~ s/&([^#])/&amp;$1/g;
	}
$tmp =~ s/&$/&amp;/g;
$tmp =~ s/\"/&quot;/g if (!$only || $only eq '"');
$tmp =~ s/\'/&#39;/g if (!$only || $only eq "'");
return $tmp;
}

=head2 quote_javascript(string)

Quote all characters that are unsafe for inclusion in javascript strings in HTML

=cut
sub quote_javascript
{
my ($str) = @_;
$str =~ s/["'<>&\\]/sprintf('\x%02x', ord $&)/ge;
return $str;
}

=head2 tempname_dir()

Returns the base directory under which temp files can be created.

=cut
sub tempname_dir
{
my $tmp_base = $gconfig{'tempdir_'.&get_module_name()} ?
			$gconfig{'tempdir_'.&get_module_name()} :
		  $gconfig{'tempdir'} ? $gconfig{'tempdir'} :
		  $ENV{'TEMP'} && $ENV{'TEMP'} ne "/tmp" ? $ENV{'TEMP'} :
		  $ENV{'TMP'} && $ENV{'TMP'} ne "/tmp" ? $ENV{'TMP'} :
		  -d "c:/temp" ? "c:/temp" : "/tmp/.webmin";
my $tmp_dir;
if (-d $remote_user_info[7] && !$gconfig{'nohometemp'}) {
	$tmp_dir = "$remote_user_info[7]/.tmp";
	}
elsif (@remote_user_info) {
	$tmp_dir = $tmp_base."-".$remote_user_info[2]."-".$remote_user;
	}
elsif ($< != 0) {
	my $u = getpwuid($<);
	if ($u) {
		$tmp_dir = $tmp_base."-".$<."-".$u;
		}
	else {
		$tmp_dir = $tmp_base."-".$<;
		}
	}
else {
	$tmp_dir = $tmp_base;
	}
return $tmp_dir;
}

=head2 tempname([filename])

Returns a mostly random temporary file name, typically under the /tmp/.webmin
directory. If filename is given, this will be the base name used. Otherwise
a unique name is selected randomly.

=cut
sub tempname
{
my ($filename) = @_;
my $tmp_dir = &tempname_dir();
if ($gconfig{'os_type'} eq 'windows' || $tmp_dir =~ /^[a-z]:/i) {
	# On Windows system, just create temp dir if missing
	if (!-d $tmp_dir) {
		mkdir($tmp_dir, 0755) ||
			&error("Failed to create temp directory $tmp_dir : $!");
		}
	}
else {
	# On Unix systems, need to make sure temp dir is valid
	my $tries = 0;
	while($tries++ < 10) {
		my @st = lstat($tmp_dir);
		last if ($st[4] == $< && (-d _) && ($st[2] & 0777) == 0755);
		if (@st) {
			unlink($tmp_dir) || rmdir($tmp_dir) ||
				system("/bin/rm -rf ".quotemeta($tmp_dir));
			}
		mkdir($tmp_dir, 0755) || next;
		chown($<, $(, $tmp_dir);
		chmod(0755, $tmp_dir);
		}
	if ($tries >= 10) {
		my @st = lstat($tmp_dir);
		&error("Failed to create temp directory $tmp_dir : uid=$st[4] mode=$st[2]");
		}
	# If running as root, check parent dir (usually /tmp) to make sure it's
	# world-writable and owned by root
	my $tmp_parent = $tmp_dir;
	$tmp_parent =~ s/\/[^\/]+$//;
	if ($tmp_parent eq "/tmp") {
		my @st = stat($tmp_parent);
		if (($st[2] & 0555) != 0555) {
			&error("Base temp directory $tmp_parent is not world readable and listable");
			}
		}
	}
my $rv;
if (defined($filename) && $filename !~ /\.\./) {
	$rv = "$tmp_dir/$filename";
	}
else {
	$main::tempfilecount++;
	&seed_random();
	$rv = $tmp_dir."/".int(rand(1000000))."_".$$."_".
	       $main::tempfilecount."_".$scriptname;
	}
return $rv;
}

=head2 transname([filename])

Behaves exactly like tempname, but records the temp file for deletion when the
current Webmin script process exits.

=cut
sub transname
{
my $rv = &tempname(@_);
push(@main::temporary_files, $rv);
return $rv;
}

=head2 trunc(string, maxlen)

Truncates a string to the shortest whole word less than or equal to the
given width. Useful for word wrapping.

=cut
sub trunc
{
if (length($_[0]) <= $_[1]) {
	return $_[0];
	}
my $str = substr($_[0],0,$_[1]);
my $c;
do {
	$c = chop($str);
	} while($c !~ /\S/);
$str =~ s/\s+$//;
return $str;
}

=head2 indexof(string, value, ...)

Returns the index of some value in an array of values, or -1 if it was not
found.

=cut
sub indexof
{
for(my $i=1; $i <= $#_; $i++) {
	if ($_[$i] eq $_[0]) { return $i - 1; }
	}
return -1;
}

=head2 indexoflc(string, value, ...)

Like indexof, but does a case-insensitive match

=cut
sub indexoflc
{
my $str = lc(shift(@_));
my @arr = map { lc($_) } @_;
return &indexof($str, @arr);
}

=head2 sysprint(handle, [string]+)

Outputs some strings to a file handle, but bypassing IO buffering. Can be used
as a replacement for print when writing to pipes or sockets.

=cut
sub sysprint
{
my $fh = &callers_package($_[0]);
my $str = join('', @_[1..$#_]);
syswrite $fh, $str, length($str);
}

=head2 check_ipaddress(ip)

Check if some IPv4 address is properly formatted, returning 1 if so or 0 if not.

=cut
sub check_ipaddress
{
return $_[0] =~ /^(\d+)\.(\d+)\.(\d+)\.(\d+)$/ &&
	$1 >= 0 && $1 <= 255 &&
	$2 >= 0 && $2 <= 255 &&
	$3 >= 0 && $3 <= 255 &&
	$4 >= 0 && $4 <= 255;
}

=head2 check_ip6address(ip)

Check if some IPv6 address is properly formatted, and returns 1 if so.

=cut
sub check_ip6address
{
  my @blocks = split(/:/, $_[0]);
  return 0 if (@blocks == 0 || @blocks > 8);

  # The address/netmask format is accepted. So we're looking for a "/" to isolate a possible netmask.
  # After that, we delete the netmask to control the address only format, but we verify whether the netmask
  # value is in [0;128].
  my $ib = $#blocks;
  my $where = index($blocks[$ib],"/");
  my $m = 0;
  if ($where != -1) {
    my $b = substr($blocks[$ib],0,$where);
    $m = substr($blocks[$ib],$where+1,length($blocks[$ib])-($where+1));
    $blocks[$ib]=$b;
  }

  # The netmask must take its value in [0;128]
  return 0 if ($m <0 || $m >128);

  # Check the different blocks of the address : 16 bits block in hexa notation.
  # Possibility of 1 empty block or 2 if the address begins with "::".
  my $b;
  my $empty = 0;
  foreach $b (@blocks) {
	  return 0 if ($b ne "" && $b !~ /^[0-9a-f]{1,4}$/i);
	  $empty++ if ($b eq "");
	  }
  return 0 if ($empty > 1 && !($_[0] =~ /^::/ && $empty == 2));
  return 1;
}



=head2 generate_icon(image, title, link, [href], [width], [height], [before-title], [after-title])

Prints HTML for an icon image. The parameters are :

=item image - URL for the image, like images/foo.gif

=item title - Text to appear under the icon

=item link - Optional destination for the icon's link

=item href - Other HTML attributes to be added to the <a href> for the link

=item width - Optional width of the icon

=item height - Optional height of the icon

=item before-title - HTML to appear before the title link, but which is not actually in the link

=item after-title - HTML to appear after the title link, but which is not actually in the link

=cut
sub generate_icon
{
&load_theme_library();
if (defined(&theme_generate_icon)) {
	&theme_generate_icon(@_);
	return;
	}
my $w = !defined($_[4]) ? "width='48'" : $_[4] ? "width='$_[4]'" : "";
my $h = !defined($_[5]) ? "height='48'" : $_[5] ? "height='$_[5]'" : "";
if ($tconfig{'noicons'}) {
	if ($_[2]) {
		print "$_[6]<a href=\"$_[2]\" $_[3]>$_[1]</a>$_[7]\n";
		}
	else {
		print "$_[6]$_[1]$_[7]\n";
		}
	}
elsif ($_[2]) {
	print "<table border><tr><td width='48' height='48'>\n",
	      "<a href=\"$_[2]\" $_[3]><img src=\"$_[0]\" alt=\"\" border='0' ",
	      "$w $h></a></td></tr></table>\n";
	print "$_[6]<a href=\"$_[2]\" $_[3]>$_[1]</a>$_[7]\n";
	}
else {
	print "<table border><tr><td width='48' height='48'>\n",
	      "<img src=\"$_[0]\" alt=\"\" border='0' $w $h>",
	      "</td></tr></table>\n$_[6]$_[1]$_[7]\n";
	}
}

=head2 urlize

Converts a string to a form ok for putting in a URL, using % escaping.

=cut
sub urlize
{
my ($rv) = @_;
$rv =~ s/([^A-Za-z0-9])/sprintf("%%%2.2X", ord($1))/ge;
return $rv;
}

=head2 un_urlize(string)

Converts a URL-encoded string to it's original contents - the reverse of the
urlize function.

=cut
sub un_urlize
{
my ($rv) = @_;
$rv =~ s/\+/ /g;
$rv =~ s/%(..)/pack("c",hex($1))/ge;
return $rv;
}

=head2 include(filename)

Read and output the contents of the given file.

=cut
sub include
{
local $_;
open(INCLUDE, &translate_filename($_[0])) || return 0;
while(<INCLUDE>) {
	print;
	}
close(INCLUDE);
return 1;
}

=head2 copydata(in-handle, out-handle)

Read from one file handle and write to another, until there is no more to read.

=cut
sub copydata
{
my ($in, $out) = @_;
$in = &callers_package($in);
$out = &callers_package($out);
my $buf;
while(read($in, $buf, 32768) > 0) {
	(print $out $buf) || return 0;
	}
return 1;
}

=head2 ReadParseMime([maximum], [&cbfunc, &cbargs], [array-mode])

Read data submitted via a POST request using the multipart/form-data coding,
and store it in the global %in hash. The optional parameters are :

=item maximum - If the number of bytes of input exceeds this number, stop reading and call error.

=item cbfunc - A function reference to call after reading each block of data.

=item cbargs - Additional parameters to the callback function.

=item array-mode - If set to 1, values in %in are arrays. If set to 0, multiple values are joined with \0. If set to 2, only the first value is used.

=cut
sub ReadParseMime
{
my ($max, $cbfunc, $cbargs, $arrays) = @_;
my ($boundary, $line, $name, $got, $file, $count_lines, $max_lines);
my $err = &text('readparse_max', $max);
$ENV{'CONTENT_TYPE'} =~ /boundary=(.*)$/ || &error($text{'readparse_enc'});
if ($ENV{'CONTENT_LENGTH'} && $max && $ENV{'CONTENT_LENGTH'} > $max) {
	&error($err);
	}
&$cbfunc(0, $ENV{'CONTENT_LENGTH'}, $file, @$cbargs) if ($cbfunc);
$boundary = $1;
$count_lines = 0;
$max_lines = 1000;
<STDIN>;	# skip first boundary
while(1) {
	$name = "";
	# Read section headers
	my $lastheader;
	while(1) {
		$line = <STDIN>;
		$got += length($line);
		&$cbfunc($got, $ENV{'CONTENT_LENGTH'}, @$cbargs) if ($cbfunc);
		if ($max && $got > $max) {
			&error($err)
			}
		$line =~ tr/\r\n//d;
		last if (!$line);
		if ($line =~ /^(\S+):\s*(.*)$/) {
			$header{$lastheader = lc($1)} = $2;
			}
		elsif ($line =~ /^\s+(.*)$/) {
			$header{$lastheader} .= $line;
			}
		}

	# Parse out filename and type
	my $file;
	if ($header{'content-disposition'} =~ /^form-data(.*)/) {
		$rest = $1;
		while ($rest =~ /([a-zA-Z]*)=\"([^\"]*)\"(.*)/) {
			if ($1 eq 'name') {
				$name = $2;
				}
			else {
				my $foo = $name."_".$1;
				if ($1 eq "filename") {
					$file = $2;
					}
				if ($arrays == 1) {
					$in{$foo} ||= [];
					push(@{$in{$foo}}, $2);
					}
				elsif ($arrays == 2) {
					$in{$foo} ||= $2;
					}
				else {
					$in{$foo} .= "\0"
						if (defined($in{$foo}));
					$in{$foo} .= $2;
					}
				}
			$rest = $3;
			}
		}
	else {
		&error($text{'readparse_cdheader'});
		}

	# Save content type separately
	if ($header{'content-type'} =~ /^([^\s;]+)/) {
		my $foo = $name."_content_type";
		if ($arrays == 1) {
			$in{$foo} ||= [];
			push(@{$in{$foo}}, $1);
			}
		elsif ($arrays == 2) {
			$in{$foo} ||= $1;
			}
		else {
			$in{$foo} .= "\0" if (defined($in{$foo}));
			$in{$foo} .= $1;
			}
		}

	# Read data
	my $data = "";
	while(1) {
		$line = <STDIN>;
		$got += length($line);
		$count_lines++;
		if ($count_lines == $max_lines) {
			&$cbfunc($got, $ENV{'CONTENT_LENGTH'}, $file, @$cbargs)
				if ($cbfunc);
			$count_lines = 0;
			}
		if ($max && $got > $max) {
			#print STDERR "over limit of $max\n";
			#&error($err);
			}
		if (!$line) {
			# Unexpected EOF?
			&$cbfunc(-1, $ENV{'CONTENT_LENGTH'}, $file, @$cbargs)
				if ($cbfunc);
			return;
			}
		if (index($line, $boundary) != -1) { last; }
		$data .= $line;
		}
	chop($data); chop($data);
	if ($arrays == 1) {
		$in{$name} ||= [];
		push(@{$in{$name}}, $data);
		}
	elsif ($arrays == 2) {
		$in{$name} ||= $data;
		}
	else {
		$in{$name} .= "\0" if (defined($in{$name}));
		$in{$name} .= $data;
		}
	if (index($line,"$boundary--") != -1) { last; }
	}
&$cbfunc(-1, $ENV{'CONTENT_LENGTH'}, $file, @$cbargs) if ($cbfunc);
}

=head2 ReadParse([&hash], [method], [noplus], [array-mode])

Fills the given hash reference with CGI parameters, or uses the global hash
%in if none is given. Also sets the global variables $in and @in. The other
parameters are :

=item method - For use of this HTTP method, such as GET

=item noplus - Don't convert + in parameters to spaces.

=item array-mode - If set to 1, values in %in are arrays. If set to 0, multiple values are joined with \0. If set to 2, only the first value is used.

=cut
sub ReadParse
{
my $a = $_[0] || \%in;
%$a = ( );
my $meth = $_[1] ? $_[1] : $ENV{'REQUEST_METHOD'};
undef($in);
if ($meth eq 'POST') {
	my $clen = $ENV{'CONTENT_LENGTH'};
	&read_fully(STDIN, \$in, $clen) == $clen ||
		&error("Failed to read POST input : $!");
	}
if ($ENV{'QUERY_STRING'}) {
	if ($in) { $in .= "&".$ENV{'QUERY_STRING'}; }
	else { $in = $ENV{'QUERY_STRING'}; }
	}
@in = split(/\&/, $in);
foreach my $i (@in) {
	my ($k, $v) = split(/=/, $i, 2);
	if (!$_[2]) {
		$k =~ tr/\+/ /;
		$v =~ tr/\+/ /;
		}
	$k =~ s/%(..)/pack("c",hex($1))/ge;
	$v =~ s/%(..)/pack("c",hex($1))/ge;
	if ($_[3] == 1) {
		$a->{$k} ||= [];
		push(@{$a->{$k}}, $v);
		}
	elsif ($_[3] == 2) {
		$a->{$k} ||= $v;
		}
	else {
		$a->{$k} = defined($a->{$k}) ? $a->{$k}."\0".$v : $v;
		}
	}
}

=head2 read_fully(fh, &buffer, length)

Read data from some file handle up to the given length, even in the face
of partial reads. Reads the number of bytes read. Stores received data in the
string pointed to be the buffer reference.

=cut
sub read_fully
{
my ($fh, $buf, $len) = @_;
$fh = &callers_package($fh);
my $got = 0;
while($got < $len) {
	my $r = read(STDIN, $$buf, $len-$got, $got);
	last if ($r <= 0);
	$got += $r;
	}
return $got;
}

=head2 read_parse_mime_callback(size, totalsize, upload-id)

Called by ReadParseMime as new data arrives from a form-data POST. Only updates
the file on every 1% change though. For internal use by the upload progress
tracker.

=cut
sub read_parse_mime_callback
{
my ($size, $totalsize, $filename, $id) = @_;
return if ($gconfig{'no_upload_tracker'});
return if (!$id);

# Create the upload tracking directory - if running as non-root, this has to
# be under the user's home
my $vardir;
if ($<) {
	my @uinfo = @remote_user_info ? @remote_user_info : getpwuid($<);
	$vardir = "$uinfo[7]/.tmp";
	}
else {
	$vardir = $ENV{'WEBMIN_VAR'};
	}
if (!-d $vardir) {
	&make_dir($vardir, 0755);
	}

# Remove any upload.* files more than 1 hour old
if (!$main::read_parse_mime_callback_flushed) {
	my $now = time();
	opendir(UPDIR, $vardir);
	foreach my $f (readdir(UPDIR)) {
		next if ($f !~ /^upload\./);
		my @st = stat("$vardir/$f");
		if ($st[9] < $now-3600) {
			unlink("$vardir/$f");
			}
		}
	closedir(UPDIR);
	$main::read_parse_mime_callback_flushed++;
	}

# Only update file once per percent
my $upfile = "$vardir/upload.$id";
if ($totalsize && $size >= 0) {
	my $pc = int(100 * $size / $totalsize);
	if ($pc <= $main::read_parse_mime_callback_pc{$upfile}) {
		return;
		}
	$main::read_parse_mime_callback_pc{$upfile} = $pc;
	}

# Write to the file
&open_tempfile(UPFILE, ">$upfile");
print UPFILE $size,"\n";
print UPFILE $totalsize,"\n";
print UPFILE $filename,"\n";
&close_tempfile(UPFILE);
}

=head2 read_parse_mime_javascript(upload-id, [&fields])

Returns an onSubmit= Javascript statement to popup a window for tracking
an upload with the given ID. For internal use by the upload progress tracker.

=cut
sub read_parse_mime_javascript
{
my ($id, $fields) = @_;
return "" if ($gconfig{'no_upload_tracker'});
my $opener = "window.open(\"$gconfig{'webprefix'}/uptracker.cgi?id=$id&uid=$<\", \"uptracker\", \"toolbar=no,menubar=no,scrollbars=no,width=500,height=128\");";
if ($fields) {
	my $if = join(" || ", map { "typeof($_) != \"undefined\" && $_.value != \"\"" } @$fields);
	return "onSubmit='if ($if) { $opener }'";
	}
else {
	return "onSubmit='$opener'";
	}
}

=head2 PrintHeader(charset, [mime-type])

Outputs the HTTP headers for an HTML page. The optional charset parameter
can be used to set a character set. Normally this function is not called
directly, but is rather called by ui_print_header or header.

=cut
sub PrintHeader
{
my ($cs, $mt) = @_;
$mt ||= "text/html";
if ($pragma_no_cache || $gconfig{'pragma_no_cache'}) {
	print "pragma: no-cache\n";
	print "Expires: Thu, 1 Jan 1970 00:00:00 GMT\n";
	print "Cache-Control: no-store, no-cache, must-revalidate\n";
	print "Cache-Control: post-check=0, pre-check=0\n";
	}
if (!$gconfig{'no_frame_options'}) {
	print "X-Frame-Options: SAMEORIGIN\n";
	}
if (!$gconfig{'no_content_security_policy'}) {
	print "Content-Security-Policy: script-src 'self' 'unsafe-inline' 'unsafe-eval'; frame-src 'self'; child-src 'self'\n";
	}
if (defined($cs)) {
	print "Content-type: $mt; Charset=$cs\n\n";
	}
else {
	print "Content-type: $mt\n\n";
	}
$main::header_content_type = $mt;
}

=head2 header(title, image, [help], [config], [nomodule], [nowebmin], [rightside], [head-stuff], [body-stuff], [below])

Outputs a Webmin HTML page header with a title, including HTTP headers. The
parameters are :

=item title - The text to show at the top of the page

=item image - An image to show instead of the title text. This is typically left blank.

=item help - If set, this is the name of a help page that will be linked to in the title.

=item config - If set to 1, the title will contain a link to the module's config page.

=item nomodule - If set to 1, there will be no link in the title section to the module's index.

=item nowebmin - If set to 1, there will be no link in the title section to the Webmin index.

=item rightside - HTML to be shown on the right-hand side of the title. Can contain multiple lines, separated by <br>. Typically this is used for links to stop, start or restart servers.

=item head-stuff - HTML to be included in the <head> section of the page.

=item body-stuff - HTML attributes to be include in the <body> tag.

=item below - HTML to be displayed below the title. Typically this is used for application or server version information.

=cut
sub header
{
return if ($main::done_webmin_header++);
my $ll;
my $charset = defined($main::force_charset) ? $main::force_charset
					    : &get_charset();
&PrintHeader($charset);
&load_theme_library();
if (defined(&theme_header)) {
	$module_name = &get_module_name();
	&theme_header(@_);
	$miniserv::page_capture = 1;
	return;
	}
print "<!DOCTYPE html PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\" \"http://www.w3.org/TR/html4/loose.dtd\">\n";
print "<html style=\"height:100%\">\n";
print "<head>\n";
if (defined(&theme_prehead)) {
	&theme_prehead(@_);
	}
if ($charset) {
	print "<meta http-equiv=\"Content-Type\" ",
	      "content=\"text/html; Charset=".&quote_escape($charset)."\">\n";
	}
if (@_ > 0) {
	my $title = &get_html_title($_[0]);
        print "<title>$title</title>\n" if ($_[7] !~ /<title>/i);
	print $_[7] if ($_[7]);
	print &get_html_status_line(0);
	}
print "$tconfig{'headhtml'}\n" if ($tconfig{'headhtml'});
if ($tconfig{'headinclude'}) {
  my ($theme, $overlay) = split(' ', $gconfig{'theme'});
  my $file_contents = read_file_contents("$root_directory/$overlay/$tconfig{'headinclude'}");;
  $file_contents = replace_meta($file_contents);
  print $file_contents;
  }
print "</head>\n";
my $bgcolor = defined($tconfig{'cs_page'}) ? $tconfig{'cs_page'} :
		 defined($gconfig{'cs_page'}) ? $gconfig{'cs_page'} : "ffffff";
my $link = defined($tconfig{'cs_link'}) ? $tconfig{'cs_link'} :
	      defined($gconfig{'cs_link'}) ? $gconfig{'cs_link'} : "0000ee";
my $text = defined($tconfig{'cs_text'}) ? $tconfig{'cs_text'} :
	      defined($gconfig{'cs_text'}) ? $gconfig{'cs_text'} : "000000";
my $bgimage = defined($tconfig{'bgimage'}) ? "background=$tconfig{'bgimage'}" : "";
my $dir = $current_lang_info->{'dir'} ? "dir=\"$current_lang_info->{'dir'}\"" : "";
my $html_body = "<body bgcolor=\"#$bgcolor\" link=\"#$link\" vlink=\"#$link\" text=\"#$text\" style=\"height:100%\" $bgimage $tconfig{'inbody'} $dir $_[8]>\n";
$html_body =~ s/\s+\>/>/g;
print $html_body;

if (defined(&theme_prebody)) {
	&theme_prebody(@_);
	}

my $prebody = $tconfig{'prebody'};
if ($prebody) {
	$prebody = replace_meta($prebody);
	print "$prebody\n";
	}
	if ($tconfig{'prebodyinclude'}) {
    my ($theme, $overlay) = split(' ', $gconfig{'theme'});
    my $file_contents = read_file_contents("$root_directory/$overlay/$tconfig{'prebodyinclude'}");
    $file_contents = replace_meta($file_contents);
    print $file_contents;
		}
if (@_ > 1) {
	print $tconfig{'preheader'};
	my %this_module_info = &get_module_info(&get_module_name());
	print "<table class='header' width='100%'><tr>\n";
	if ($gconfig{'sysinfo'} == 2 && $remote_user) {
		print "<td id='headln1' colspan='3' align='center'>\n";
		print &get_html_status_line(1);
		print "</td></tr> <tr>\n";
		}
	print "<td id='headln2l' width='15%' valign='top' align='left'>";
	if ($ENV{'HTTP_WEBMIN_SERVERS'} && !$tconfig{'framed'}) {
		print "<a href='$ENV{'HTTP_WEBMIN_SERVERS'}'>",
		      "$text{'header_servers'}</a><br>\n";
		}
	if (!$_[5] && !$tconfig{'noindex'}) {
		my @avail = &get_available_module_infos(1);
		my $nolo = $ENV{'ANONYMOUS_USER'} ||
			      $ENV{'SSL_USER'} || $ENV{'LOCAL_USER'} ||
			      $ENV{'HTTP_USER_AGENT'} =~ /webmin/i;
		if ($gconfig{'gotoone'} && $main::session_id && @avail == 1 &&
		    !$nolo) {
			print "<a href='$gconfig{'webprefix'}/session_login.cgi?logout=1'>",
			      "$text{'main_logout'}</a><br>";
			}
		elsif ($gconfig{'gotoone'} && @avail == 1 && !$nolo) {
			print "<a href=$gconfig{'webprefix'}/switch_user.cgi>",
			      "$text{'main_switch'}</a><br>";
			}
		elsif (!$gconfig{'gotoone'} || @avail > 1) {
			print "<a href='$gconfig{'webprefix'}/?cat=",
			      $this_module_info{'category'},
			      "'>$text{'header_webmin'}</a><br>\n";
			}
		}
	if (!$_[4] && !$tconfig{'nomoduleindex'}) {
		my $idx = $this_module_info{'index_link'};
		my $mi = $module_index_link || "/".&get_module_name()."/$idx";
		my $mt = $module_index_name || $text{'header_module'};
		print "<a href=\"$gconfig{'webprefix'}$mi\">$mt</a><br>\n";
		}
	if (ref($_[2]) eq "ARRAY" && !$ENV{'ANONYMOUS_USER'} &&
	    !$tconfig{'nohelp'}) {
		print &hlink($text{'header_help'}, $_[2]->[0], $_[2]->[1]),
		      "<br>\n";
		}
	elsif (defined($_[2]) && !$ENV{'ANONYMOUS_USER'} &&
	       !$tconfig{'nohelp'}) {
		print &hlink($text{'header_help'}, $_[2]),"<br>\n";
		}
	if ($_[3]) {
		my %access = &get_module_acl();
		if (!$access{'noconfig'} && !$config{'noprefs'}) {
			my $cprog = $user_module_config_directory ?
					"uconfig.cgi" : "config.cgi";
			print "<a href=\"$gconfig{'webprefix'}/$cprog?",
			      &get_module_name()."\">",
			      $text{'header_config'},"</a><br>\n";
			}
		}
	print "</td>\n";
	if ($_[1]) {
		# Title is a single image
		print "<td id='headln2c' align='center' width='70%'>",
		      "<img alt=\"$_[0]\" src=\"$_[1]\"></td>\n";
		}
	else {
		# Title is just text
		my $ts = defined($tconfig{'titlesize'}) ?
				$tconfig{'titlesize'} : "+2";
		print "<td id='headln2c' align='center' width='70%'>",
		      ($ts ? "<font size='$ts'>" : ""),$_[0],
		      ($ts ? "</font>" : "");
		print "<br>$_[9]\n" if ($_[9]);
		print "</td>\n";
		}
	print "<td id='headln2r' width='15%' valign='top' align='right'>";
	print $_[6];
	print "</td></tr></table>\n";
	print $tconfig{'postheader'};
	}
$miniserv::page_capture = 1;
}

=head2 get_html_title(title)

Returns the full string to appear in the HTML <title> block.

=cut
sub get_html_title
{
my ($msg) = @_;
my $title;
my $os_type = $gconfig{'real_os_type'} || $gconfig{'os_type'};
my $os_version = $gconfig{'real_os_version'} || $gconfig{'os_version'};
my $host = &get_display_hostname();
if ($gconfig{'sysinfo'} == 1 && $remote_user) {
	$title = sprintf "%s : %s on %s (%s %s)\n",
		$msg, $remote_user, $host,
		$os_type, $os_version;
	}
elsif ($gconfig{'sysinfo'} == 4 && $remote_user) {
	$title = sprintf "%s on %s (%s %s)\n",
		$remote_user, $host,
		$os_type, $os_version;
	}
else {
	$title = $msg;
	}
if ($gconfig{'showlogin'} && $remote_user) {
	$title = $remote_user.($title ? " : ".$title : "");
	}
if ($gconfig{'showhost'}) {
	$title = $host.($title ? " : ".$title : "");
	}
return $title;
}

=head2 get_html_framed_title

Returns the title text for a framed theme main page.

=cut
sub get_html_framed_title
{
my $ostr;
my $os_type = $gconfig{'real_os_type'} || $gconfig{'os_type'};
my $os_version = $gconfig{'real_os_version'} || $gconfig{'os_version'};
my $title;
if (($gconfig{'sysinfo'} == 4 || $gconfig{'sysinfo'} == 1) && $remote_user) {
	# Alternate title mode requested
	$title = sprintf "%s on %s (%s %s)\n",
		$remote_user, &get_display_hostname(),
		$os_type, $os_version;
	}
else {
	# Title like 'Webmin x.yy on hostname (Linux 6)'
	if ($os_version eq "*") {
		$ostr = $os_type;
		}
	else {
		$ostr = "$os_type $os_version";
		}
	my $host = &get_display_hostname();
	my $ver = &get_webmin_version();
	$title = $gconfig{'nohostname'} ? $text{'main_title2'} :
		 $gconfig{'showhost'} ? &text('main_title3', $ver, $ostr) :
					&text('main_title', $ver, $host, $ostr);
	if ($gconfig{'showlogin'}) {
		$title = $remote_user.($title ? " : ".$title : "");
		}
	if ($gconfig{'showhost'}) {
		$title = $host.($title ? " : ".$title : "");
		}
	}
return $title;
}

=head2 get_html_status_line(text-only)

Returns HTML for a script block that sets the status line, or if text-only
is set to 1, just return the status line text.

=cut
sub get_html_status_line
{
my ($textonly) = @_;
if (($gconfig{'sysinfo'} != 0 || !$remote_user) && !$textonly) {
	# Disabled in this mode
	return undef;
	}
my $os_type = $gconfig{'real_os_type'} || $gconfig{'os_type'};
my $os_version = $gconfig{'real_os_version'} || $gconfig{'os_version'};
my $line = &text('header_statusmsg',
		 ($ENV{'ANONYMOUS_USER'} ? "Anonymous user"
					   : $remote_user).
		 ($ENV{'SSL_USER'} ? " (SSL certified)" :
		  $ENV{'LOCAL_USER'} ? " (Local user)" : ""),
		 $text{'programname'},
		 &get_webmin_version(),
		 &get_display_hostname(),
		 $os_type.($os_version eq "*" ? "" :" $os_version"));
if ($textonly) {
	return $line;
	}
else {
	$line =~ s/\r|\n//g;
	return "<script type='text/javascript'>\n".
	       "window.defaultStatus=\"".&quote_escape($line)."\";\n".
	       "</script>\n";
	}
}

=head2 popup_header([title], [head-stuff], [body-stuff], [no-body])

Outputs a page header, suitable for a popup window. If no title is given,
absolutely no decorations are output. Also useful in framesets. The parameters
are :

=item title - Title text for the popup window.

=item head-stuff - HTML to appear in the <head> section.

=item body-stuff - HTML attributes to be include in the <body> tag.

=item no-body - If set to 1, don't generate a body tag

=cut
sub popup_header
{
return if ($main::done_webmin_header++);
my $ll;
my $charset = defined($main::force_charset) ? $main::force_charset
					    : &get_charset();
&PrintHeader($charset);
&load_theme_library();
if (defined(&theme_popup_header)) {
	&theme_popup_header(@_);
	$miniserv::page_capture = 1;
	return;
	}
print "<!DOCTYPE html PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\" \"http://www.w3.org/TR/html4/loose.dtd\">\n";
print "<html>\n";
print "<head>\n";
if (defined(&theme_popup_prehead)) {
	&theme_popup_prehead(@_);
	}
print "<title>$_[0]</title>\n";
print $_[1];
print "$tconfig{'headhtml'}\n" if ($tconfig{'headhtml'});
if ($tconfig{'headinclude'}) {
	print &read_file_contents(
		"$theme_root_directory/$tconfig{'headinclude'}");
	}
print "</head>\n";
my $bgcolor = defined($tconfig{'cs_page'}) ? $tconfig{'cs_page'} :
		 defined($gconfig{'cs_page'}) ? $gconfig{'cs_page'} : "ffffff";
my $link = defined($tconfig{'cs_link'}) ? $tconfig{'cs_link'} :
	      defined($gconfig{'cs_link'}) ? $gconfig{'cs_link'} : "0000ee";
my $text = defined($tconfig{'cs_text'}) ? $tconfig{'cs_text'} :
	      defined($gconfig{'cs_text'}) ? $gconfig{'cs_text'} : "000000";
my $bgimage = defined($tconfig{'bgimage'}) ? "background='$tconfig{'bgimage'}'"
					      : "";
if (!$_[3]) {
	print "<body id='popup' bgcolor='#$bgcolor' link='#$link' vlink='#$link' ",
	      "text='#$text' $bgimage $tconfig{'inbody'} $_[2]>\n";
	if (defined(&theme_popup_prebody)) {
		&theme_popup_prebody(@_);
		}
	}
$miniserv::page_capture = 1;
}

=head2 footer([page, name]+, [noendbody])

Outputs the footer for a Webmin HTML page, possibly with links back to other
pages. The links are specified by pairs of parameters, the first of which is
a link destination, and the second the link text. For example :

 footer('/', 'Webmin index', '', 'Module menu');

=cut
sub footer
{
$miniserv::page_capture = 0;
&load_theme_library();
my %this_module_info = &get_module_info(&get_module_name());
if (defined(&theme_footer)) {
	$module_name = &get_module_name();	# Old themes use these
	%module_info = %this_module_info;
	&theme_footer(@_);
	return;
	}
for(my $i=0; $i+1<@_; $i+=2) {
	my $url = $_[$i];
	if ($url ne '/' || !$tconfig{'noindex'}) {
		if ($url eq '/') {
			$url = "/?cat=$this_module_info{'category'}";
			}
		elsif ($url eq '' && &get_module_name()) {
			$url = "/".&get_module_name()."/".
			       $this_module_info{'index_link'};
			}
		elsif ($url =~ /^\?/ && &get_module_name()) {
			$url = "/".&get_module_name()."/$url";
			}
		$url = "$gconfig{'webprefix'}$url" if ($url =~ /^\//);
		if ($i == 0) {
			print "<a href=\"$url\"><img alt=\"<-\" align='middle' border='0' src='$gconfig{'webprefix'}/images/left.gif'></a>\n";
			}
		else {
			print "&nbsp;|\n";
			}
		print "&nbsp;<a href=\"$url\">",&text('main_return', $_[$i+1]),"</a>\n";
		}
	}
print "<br>\n";
if (!$_[$i]) {
	my $postbody = $tconfig{'postbody'};
	if ($postbody) {
		$postbody = replace_meta($postbody);
		print "$postbody\n";
		}
	if ($tconfig{'postbodyinclude'}) {
    my ($theme, $overlay) = split(' ', $gconfig{'theme'});
    my $file_contents = read_file_contents("$root_directory/$overlay/$tconfig{'postbodyinclude'}");
    $file_contents = replace_meta($file_contents);
    print $file_contents;
    }
	if (defined(&theme_postbody)) {
		&theme_postbody(@_);
		}
	print "</body></html>\n";
	}
}

=head2 popup_footer([no-body])

Outputs html for a footer for a popup window, started by popup_header.

=cut
sub popup_footer
{
$miniserv::page_capture = 0;
&load_theme_library();
if (defined(&theme_popup_footer)) {
	&theme_popup_footer(@_);
	return;
	}
if (!$_[0]) {
	print "</body>\n";
	}
print "</html>\n";
}

=head2 load_theme_library

Immediately loads the current theme's theme.pl file. Not generally useful for
most module developers, as this is called automatically by the header function.

=cut
sub load_theme_library
{
return if (!$current_theme || $loaded_theme_library++);
for(my $i=0; $i<@theme_root_directories; $i++) {
	if ($theme_configs[$i]->{'functions'}) {
		do $theme_root_directories[$i]."/".
		   $theme_configs[$i]->{'functions'};
		}
	}
}

=head2 redirect(url)

Output HTTP headers to redirect the browser to some page. The url parameter is
typically a relative URL like index.cgi or list_users.cgi.

=cut
sub redirect
{
my $port = $ENV{'SERVER_PORT'} == 443 && uc($ENV{'HTTPS'}) eq "ON" ? "" :
	   $ENV{'SERVER_PORT'} == 80 && uc($ENV{'HTTPS'}) ne "ON" ? "" :
		":$ENV{'SERVER_PORT'}";
my $prot = uc($ENV{'HTTPS'}) eq "ON" ? "https" : "http";
my $wp = $gconfig{'webprefixnoredir'} ? undef : $gconfig{'webprefix'};
my $url;
if ($_[0] =~ /^(http|https|ftp|gopher):/) {
	# Absolute URL (like http://...)
	$url = $_[0];
	}
elsif ($_[0] =~ /^\//) {
	# Absolute path (like /foo/bar.cgi)
	if ($gconfig{'relative_redir'}) {
		$url = "$wp$_[0]";
		}
	else {
		$url = "$prot://$ENV{'SERVER_NAME'}$port$wp$_[0]";
		}
	}
elsif ($ENV{'SCRIPT_NAME'} =~ /^(.*)\/[^\/]*$/) {
	# Relative URL (like foo.cgi)
	if ($gconfig{'relative_redir'}) {
		$url = "$wp$1/$_[0]";
		}
	else {
		$url = "$prot://$ENV{'SERVER_NAME'}$port$wp$1/$_[0]";
		}
	}
else {
	if ($gconfig{'relative_redir'}) {
		$url = "$wp$_[0]";
		}
	else {
		$url = "$prot://$ENV{'SERVER_NAME'}$port/$wp$_[0]";
		}
	}
&load_theme_library();
if (defined(&theme_redirect)) {
	$module_name = &get_module_name();	# Old themes use these
	%module_info = &get_module_info($module_name);
	&theme_redirect($_[0], $url);
	}
else {
	print "Location: $url\n\n";
	}
}

=head2 kill_byname(name, signal)

Finds a process whose command line contains the given name (such as httpd), and
sends some signal to it. The signal can be numeric (like 9) or named
(like KILL).

=cut
sub kill_byname
{
my @pids = &find_byname($_[0]);
return scalar(@pids) if (&is_readonly_mode());
&webmin_debug_log('KILL', "signal=$_[1] name=$_[0]")
	if ($gconfig{'debug_what_procs'});
if (@pids) { kill($_[1], @pids); return scalar(@pids); }
else { return 0; }
}

=head2 kill_byname_logged(name, signal)

Like kill_byname, but also logs the killing.

=cut
sub kill_byname_logged
{
my @pids = &find_byname($_[0]);
return scalar(@pids) if (&is_readonly_mode());
if (@pids) { &kill_logged($_[1], @pids); return scalar(@pids); }
else { return 0; }
}

=head2 find_byname(name)

Finds processes searching for the given name in their command lines, and
returns a list of matching PIDs.

=cut
sub find_byname
{
if ($gconfig{'os_type'} =~ /-linux$/ && -r "/proc/$$/cmdline") {
	# Linux with /proc filesystem .. use cmdline files, as this is
	# faster than forking
	my @pids;
	opendir(PROCDIR, "/proc");
	foreach my $f (readdir(PROCDIR)) {
		if ($f eq int($f) && $f != $$) {
			my $line = &read_file_contents("/proc/$f/cmdline");
			if ($line =~ /$_[0]/) {
				push(@pids, $f);
				}
			}
		}
	closedir(PROCDIR);
	return @pids;
	}

if (&foreign_check("proc")) {
	# Call the proc module
	&foreign_require("proc", "proc-lib.pl");
	if (defined(&proc::list_processes)) {
		my @procs = &proc::list_processes();
		my @pids;
		foreach my $p (@procs) {
			if ($p->{'args'} =~ /$_[0]/) {
				push(@pids, $p->{'pid'});
				}
			}
		@pids = grep { $_ != $$ } @pids;
		return @pids;
		}
	}

# Fall back to running a command
my ($cmd, @pids);
$cmd = $gconfig{'find_pid_command'};
$cmd =~ s/NAME/"$_[0]"/g;
$cmd = &translate_command($cmd);
@pids = split(/\n/, `($cmd) <$null_file 2>$null_file`);
@pids = grep { $_ != $$ } @pids;
return @pids;
}

=head2 error([message]+)

Display an error message and exit. This should be used by CGI scripts that
encounter a fatal error or invalid user input to notify users of the problem.
If error_setup has been called, the displayed error message will be prefixed
by the message setup using that function.

=cut
sub error
{
$main::no_miniserv_userdb = 1;
my $msg = join("", @_);
$msg =~ s/<[^>]*>//g;
if (!$main::error_must_die) {
	print STDERR "Error: ",$msg,"\n";
	}
&load_theme_library();
if ($main::error_must_die) {
	if ($gconfig{'error_stack'}) {
		print STDERR "Error: ",$msg,"\n";
		for(my $i=0; my @stack = caller($i); $i++) {
			print STDERR "File: $stack[1] Line: $stack[2] ",
				     "Function: $stack[3]\n";
			}
		}
	die @_;
	}
&call_error_handlers();
if (!$ENV{'REQUEST_METHOD'}) {
	# Show text-only error
	print STDERR "$text{'error'}\n";
	print STDERR "-----\n";
	print STDERR ($main::whatfailed ? "$main::whatfailed : " : ""),
		     $msg,"\n";
	print STDERR "-----\n";
	if ($gconfig{'error_stack'}) {
		# Show call stack
		print STDERR $text{'error_stack'},"\n";
		for(my $i=0; my @stack = caller($i); $i++) {
			print STDERR &text('error_stackline',
				$stack[1], $stack[2], $stack[3]),"\n";
			}
		}

	}
elsif (defined(&theme_error)) {
	&theme_error(@_);
	}
elsif ($in{'json-error'} eq '1') {
	my %jerror;
	my $error_what = ($main::whatfailed ? "$main::whatfailed: " : "");
	my $error_message = join(",", @_);
	my $error = ($error_what . $error_message);
	%jerror = (error => $error,
		   error_fatal => 1, 
		   error_what => $error_what, 
		   error_message => $error_message
		  );
	print_json(\%jerror);
	}
else {
	&header($text{'error'}, "");
	print "<hr>\n";
	print "<h3>",($main::whatfailed ? "$main::whatfailed : " : ""),
		     @_,"</h3>\n";
	if ($gconfig{'error_stack'}) {
		# Show call stack
		print "<h3>$text{'error_stack'}</h3>\n";
		print "<table>\n";
		print "<tr> <td><b>$text{'error_file'}</b></td> ",
		      "<td><b>$text{'error_line'}</b></td> ",
		      "<td><b>$text{'error_sub'}</b></td> </tr>\n";
		for($i=0; my @stack = caller($i); $i++) {
			print "<tr>\n";
			print "<td>$stack[1]</td>\n";
			print "<td>$stack[2]</td>\n";
			print "<td>$stack[3]</td>\n";
			print "</tr>\n";
			}
		print "</table>\n";
		}
	print "<hr>\n";
	if ($ENV{'HTTP_REFERER'} && $main::completed_referers_check) {
		&footer("javascript:history.back()", $text{'error_previous'});
		}
	else {
		&footer();
		}
	}
&unlock_all_files();
&cleanup_tempnames();
exit(1);
}

=head2 popup_error([message]+)

This function is almost identical to error, but displays the message with HTML
headers suitable for a popup window.

=cut
sub popup_error
{
$main::no_miniserv_userdb = 1;
&load_theme_library();
if ($main::error_must_die) {
	die @_;
	}
&call_error_handlers();
if (defined(&theme_popup_error)) {
	&theme_popup_error(@_);
	}
else {
	&popup_header($text{'error'}, "");
	print "<h3>",($main::whatfailed ? "$main::whatfailed : " : ""),@_,"</h3>\n";
	&popup_footer();
	}
&unlock_all_files();
&cleanup_tempnames();
exit;
}

=head2 register_error_handler(&func, arg, ...)

Register a function that will be called when this process exits, such as by
calling &error

=cut
sub register_error_handler
{
my ($f, @args) = @_;
push(@$error_handler_funcs, [ $f, @args ]);
}


=head2 call_error_handlers()

Internal function to call all registered error handlers

=cut
sub call_error_handlers
{
my @funcs = @$error_handler_funcs;
$error_handler_funcs = [ ];
foreach my $e (@funcs) {
	my ($f, @args) = @$e;
	&$f(@args);
	}
}

=head2 error_setup(message)

Registers a message to be prepended to all error messages displayed by the
error function.

=cut
sub error_setup
{
$main::whatfailed = $_[0];
}

=head2 wait_for(handle, regexp, regexp, ...)

Reads from the input stream until one of the regexps matches, and returns the
index of the matching regexp, or -1 if input ended before any matched. This is
very useful for parsing the output of interactive programs, and can be used with
a two-way pipe to feed input to a program in response to output matched by
this function.

If the matching regexp contains bracketed sub-expressions, their values will
be placed in the global array @matches, indexed starting from 1. You cannot
use the Perl variables $1, $2 and so on to capture matches.

Example code:

 $rv = wait_for($loginfh, "username:");
 if ($rv == -1) {
   error("Didn't get username prompt");
 }
 print $loginfh "joe\n";
 $rv = wait_for($loginfh, "password:");
 if ($rv == -1) {
   error("Didn't get password prompt");
 }
 print $loginfh "smeg\n";

=cut
sub wait_for
{
my ($c, $i, $sw, $rv, $ha);
undef($wait_for_input);
if ($wait_for_debug) {
	print STDERR "wait_for(",join(",", @_),")\n";
	}
$ha = &callers_package($_[0]);
if ($wait_for_debug) {
	print STDERR "File handle=$ha fd=",fileno($ha),"\n";
	}
$codes =
"my \$hit;\n".
"while(1) {\n".
" if ((\$c = getc(\$ha)) eq \"\") { return -1; }\n".
" \$wait_for_input .= \$c;\n";
if ($wait_for_debug) {
	$codes .= "print STDERR \$wait_for_input,\"\\n\";";
	}
for($i=1; $i<@_; $i++) {
        $sw = $i>1 ? "elsif" : "if";
        $codes .= " $sw (\$wait_for_input =~ /$_[$i]/i) { \$hit = $i-1; }\n";
        }
$codes .=
" if (defined(\$hit)) {\n".
"  \@matches = (-1, \$1, \$2, \$3, \$4, \$5, \$6, \$7, \$8, \$9);\n".
"  return \$hit;\n".
"  }\n".
" }\n";
$rv = eval $codes;
if ($@) {
	&error("wait_for error : $@\n");
	}
return $rv;
}

=head2 fast_wait_for(handle, string, string, ...)

This function behaves very similar to wait_for (documented above), but instead
of taking regular expressions as parameters, it takes strings. As soon as the
input contains one of them, it will return the index of the matching string.
If the input ends before any match, it returns -1.

=cut
sub fast_wait_for
{
my ($inp, $maxlen, $ha, $i, $c, $inpl);
for($i=1; $i<@_; $i++) {
	$maxlen = length($_[$i]) > $maxlen ? length($_[$i]) : $maxlen;
	}
$ha = $_[0];
while(1) {
	if (($c = getc($ha)) eq "") {
		&error("fast_wait_for read error : $!");
		}
	$inp .= $c;
	if (length($inp) > $maxlen) {
		$inp = substr($inp, length($inp)-$maxlen);
		}
	$inpl = length($inp);
	for($i=1; $i<@_; $i++) {
		if ($_[$i] eq substr($inp, $inpl-length($_[$i]))) {
			return $i-1;
			}
		}
	}
}

=head2 has_command(command)

Returns the full path to the executable if some command is in the path, or
undef if not found. If the given command is already an absolute path and
exists, then the same path will be returned.

=cut
sub has_command
{
if (!$_[0]) { return undef; }
if (exists($main::has_command_cache{$_[0]})) {
	return $main::has_command_cache{$_[0]};
	}
my $rv = undef;
my $slash = $gconfig{'os_type'} eq 'windows' ? '\\' : '/';
if ($_[0] =~ /^\// || $_[0] =~ /^[a-z]:[\\\/]/i) {
	# Absolute path given - just use it
	my $t = &translate_filename($_[0]);
	$rv = (-x $t && !-d _) ? $_[0] : undef;
	}
else {
	# Check each directory in the path
	my %donedir;
	foreach my $d (split($path_separator, $ENV{'PATH'})) {
		next if ($donedir{$d}++);
		$d =~ s/$slash$// if ($d ne $slash);
		my $t = &translate_filename("$d/$_[0]");
		if (-x $t && !-d _) {
			$rv = $d.$slash.$_[0];
			last;
			}
		if ($gconfig{'os_type'} eq 'windows') {
			foreach my $sfx (".exe", ".com", ".bat") {
				my $t = &translate_filename("$d/$_[0]").$sfx;
				if (-r $t && !-d _) {
					$rv = $d.$slash.$_[0].$sfx;
					last;
					}
				}
			}
		}
	}
$main::has_command_cache{$_[0]} = $rv;
return $rv;
}

=head2 make_date(seconds, [date-only], [fmt])

Converts a Unix date/time in seconds to a human-readable form, by default
formatted like dd/mmm/yyyy hh:mm:ss. Parameters are :

=item seconds - Unix time is seconds to convert.

=item date-only - If set to 1, exclude the time from the returned string.

=item fmt - Optional, one of dd/mon/yyyy, dd/mm/yyyy, mm/dd/yyyy or yyyy/mm/dd

=cut
sub make_date
{
&load_theme_library();
if (defined(&theme_make_date) &&
    $main::header_content_type eq "text/html" &&
    $main::webmin_script_type eq "web") {
	return &theme_make_date(@_);
	}
my ($secs, $only, $fmt) = @_;
my @tm = localtime($secs);
my $date;
if (!$fmt) {
	$fmt = $gconfig{'dateformat'} || 'dd/mon/yyyy';
	}
if ($fmt eq 'dd/mon/yyyy') {
	$date = sprintf "%2.2d/%s/%4.4d",
			$tm[3], $text{"smonth_".($tm[4]+1)}, $tm[5]+1900;
	}
elsif ($fmt eq 'dd/mm/yyyy') {
	$date = sprintf "%2.2d/%2.2d/%4.4d", $tm[3], $tm[4]+1, $tm[5]+1900;
	}
elsif ($fmt eq 'mm/dd/yyyy') {
	$date = sprintf "%2.2d/%2.2d/%4.4d", $tm[4]+1, $tm[3], $tm[5]+1900;
	}
elsif ($fmt eq 'yyyy/mm/dd') {
	$date = sprintf "%4.4d/%2.2d/%2.2d", $tm[5]+1900, $tm[4]+1, $tm[3];
	}
elsif ($fmt eq 'd. mon yyyy') {
	$date = sprintf "%d. %s %4.4d",
			$tm[3], $text{"smonth_".($tm[4]+1)}, $tm[5]+1900;
	}
elsif ($fmt eq 'dd.mm.yyyy') {
	$date = sprintf "%2.2d.%2.2d.%4.4d", $tm[3], $tm[4]+1, $tm[5]+1900;
	}
elsif ($fmt eq 'yyyy-mm-dd') {
	$date = sprintf "%4.4d-%2.2d-%2.2d", $tm[5]+1900, $tm[4]+1, $tm[3];
	}
if (!$only) {
	$date .= sprintf " %2.2d:%2.2d", $tm[2], $tm[1];
	}
return $date;
}

=head2 file_chooser_button(input, type, [form], [chroot], [addmode])

Return HTML for a button that pops up a file chooser when clicked, and places
the selected filename into another HTML field. The parameters are :

=item input - Name of the form field to store the filename in.

=item type - 0 for file or directory chooser, or 1 for directory only.

=item form - Index of the form containing the button.

=item chroot - If set to 1, the chooser will be limited to this directory.

=item addmode - If set to 1, the selected filename will be appended to the text box instead of replacing it's contents.

=cut
sub file_chooser_button
{
return &theme_file_chooser_button(@_)
	if (defined(&theme_file_chooser_button));
my $form = defined($_[2]) ? $_[2] : 0;
my $chroot = defined($_[3]) ? $_[3] : "/";
my $add = int($_[4]);
my ($w, $h) = (400, 300);
if ($gconfig{'db_sizefile'}) {
	($w, $h) = split(/x/, $gconfig{'db_sizefile'});
	}
return "<input type=button onClick='ifield = form.$_[0]; chooser = window.open(\"$gconfig{'webprefix'}/chooser.cgi?add=$add&type=$_[1]&chroot=$chroot&file=\"+encodeURIComponent(ifield.value), \"chooser\", \"toolbar=no,menubar=no,scrollbars=no,resizable=yes,width=$w,height=$h\"); chooser.ifield = ifield; window.ifield = ifield' value=\"...\">\n";
}

=head2 popup_window_button(url, width, height, scrollbars?, &field-mappings)

Returns HTML for a button that will popup a chooser window of some kind. The
parameters are :

=item url - Base URL of the popup window's contents

=item width - Width of the window in pixels

=item height - Height in pixels

=item scrollbars - Set to 1 if the window should have scrollbars

=item fields - See below

=item disabled - The button is disabled if non-zero

The field-mappings parameter is an array ref of array refs containing

=item - Attribute to assign field to in the popup window

=item - Form field name

=item - CGI parameter to URL for value, if any

=cut
sub popup_window_button
{
return &theme_popup_window_button(@_) if (defined(&theme_popup_window_button));
my ($url, $w, $h, $scroll, $fields, $disabled) = @_;
my $scrollyn = $scroll ? "yes" : "no";
my $rv = "<input type=button onClick='";
foreach my $m (@$fields) {
	$rv .= "$m->[0] = form.$m->[1]; ";
	}
my $sep = $url =~ /\?/ ? "&" : "?";
$rv .= "chooser = window.open(\"$url\"";
foreach my $m (@$fields) {
	if ($m->[2]) {
		$rv .= "+\"$sep$m->[2]=\"+escape($m->[0].value)";
		$sep = "&";
		}
	}
$rv .= ", \"chooser\", \"toolbar=no,menubar=no,scrollbars=$scrollyn,resizable=yes,width=$w,height=$h\"); ";
foreach my $m (@$fields) {
	$rv .= "chooser.$m->[0] = $m->[0]; ";
	$rv .= "window.$m->[0] = $m->[0]; ";
	}
$rv .= "' value=\"...\"";
if ($disabled) {
	$rv .= " disabled";
	}
$rv .= ">";
return $rv;
}

=head2 popup_window_link(url, title, width, height, scrollbar, &field-mappings)

Returns HTML for a link that will popup a chooser window of some kind. The
parameters are :

=item url - Base URL of the popup window's contents

=item title - Text of the link

=item width - Width of the window in pixels

=item height - Height in pixels

=item scrollbars - Set to 1 if the window should have scrollbars

=item fields - See below

The field-mappings parameter is an array ref of array refs containing

=item - Attribute to assign field to in the popup window

=item - Form field name

=item - CGI parameter to URL for value, if any

=cut
sub popup_window_link
{
return &theme_popup_window_link(@_) if (defined(&theme_popup_window_link));
my ($url, $title, $w, $h, $scrollyn, $fields) = @_;
my $scrollyn = $scroll ? "yes" : "no";
my $rv = "onClick='";
foreach my $m (@$fields) {
	$rv .= "$m->[0] = form.$m->[1]; ";
	}
my $sep = $url =~ /\?/ ? "&" : "?";
$rv .= "chooser = window.open(\"$url\"";
foreach my $m (@$fields) {
	if ($m->[2]) {
		$rv .= "+\"$sep$m->[2]=\"+escape($m->[0].value)";
		$sep = "&";
		}
	}
$rv .= ", \"chooser\", \"toolbar=no,menubar=no,scrollbars=$scrollyn,resizable=yes,width=$w,height=$h\"); ";
foreach my $m (@$fields) {
	$rv .= "chooser.$m->[0] = $m->[0]; ";
	$rv .= "window.$m->[0] = $m->[0]; ";
	}
$rv .= "return false;'";
return &ui_link($url, $title, undef, $rv);
}

=head2 read_acl(&user-module-hash, &user-list-hash, [&only-users])

Reads the Webmin acl file into the given hash references. The first is indexed
by a combined key of username,module , with the value being set to 1 when
the user has access to that module. The second is indexed by username, with
the value being an array ref of allowed modules.

This function is deprecated in favour of foreign_available, which performs a
more comprehensive check of module availability.

If the only-users array ref parameter is given, the results may be limited to
users in that list of names.

=cut
sub read_acl
{
my ($usermod, $userlist, $only) = @_;
if (!%main::acl_hash_cache) {
	# Read from local files
	local $_;
	open(ACL, &acl_filename());
	while(<ACL>) {
		if (/^([^:]+):\s*(.*)/) {
			my $user = $1;
			my @mods = split(/\s+/, $2);
			foreach my $m (@mods) {
				$main::acl_hash_cache{$user,$m}++;
				}
			$main::acl_array_cache{$user} = \@mods;
			}
		}
	close(ACL);
	}
%$usermod = %main::acl_hash_cache if ($usermod);
%$userlist = %main::acl_array_cache if ($userlist);

# Read from user DB
my $userdb = &get_userdb_string();
my ($dbh, $proto, $prefix, $args) =
	$userdb ? &connect_userdb($userdb) : ( );
if (ref($dbh)) {
	if ($proto eq "mysql" || $proto eq "postgresql") {
		# Select usernames and modules from SQL DB
		my $cmd = $dbh->prepare(
			"select webmin_user.name,webmin_user_attr.value ".
			"from webmin_user,webmin_user_attr ".
			"where webmin_user.id = webmin_user_attr.id ".
			"and webmin_user_attr.attr = 'modules' ".
			($only ? " and webmin_user.name in (".
				 join(",", map { "'$_'" } @$only).")" : ""));
		if ($cmd && $cmd->execute()) {
			while(my ($user, $mods) = $cmd->fetchrow()) {
				my @mods = split(/\s+/, $mods);
				foreach my $m (@mods) {
					$usermod->{$user,$m}++ if ($usermod);
					}
				$userlist->{$user} = \@mods if ($userlist);
				}
			}
		$cmd->finish() if ($cmd);
		}
	elsif ($proto eq "ldap") {
		# Find users in LDAP
		my $filter = '(objectClass='.$args->{'userclass'}.')';
		if ($only) {
			my $ufilter =
				"(|".join("", map { "(cn=$_)" } @$only).")";
			$filter = "(&".$filter.$ufilter.")";
			}
		my $rv = $dbh->search(
			base => $prefix,
			filter => $filter,
			scope => 'sub',
			attrs => [ 'cn', 'webminModule' ]);
		if ($rv && !$rv->code) {
			foreach my $u ($rv->all_entries) {
				my $user = $u->get_value('cn');
				my @mods =$u->get_value('webminModule');
				foreach my $m (@mods) {
					$usermod->{$user,$m}++ if ($usermod);
					}
				$userlist->{$user} = \@mods if ($userlist);
				}
			}
		}
	&disconnect_userdb($userdb, $dbh);
	}
}

=head2 acl_filename

Returns the file containing the webmin ACL, which is usually
/etc/webmin/webmin.acl.

=cut
sub acl_filename
{
return "$config_directory/webmin.acl";
}

=head2 acl_check

Does nothing, but kept around for compatibility.

=cut
sub acl_check
{
}

=head2 get_miniserv_config(&hash)

Reads the Webmin webserver's (miniserv.pl) configuration file, usually located
at /etc/webmin/miniserv.conf, and stores its names and values in the given
hash reference.

=cut
sub get_miniserv_config
{
return &read_file_cached(
	$ENV{'MINISERV_CONFIG'} || "$config_directory/miniserv.conf", $_[0]);
}

=head2 put_miniserv_config(&hash)

Writes out the Webmin webserver configuration file from the contents of
the given hash ref. This should be initially populated by get_miniserv_config,
like so :

 get_miniserv_config(\%miniserv);
 $miniserv{'port'} = 10005;
 put_miniserv_config(\%miniserv);
 restart_miniserv();

=cut
sub put_miniserv_config
{
&write_file($ENV{'MINISERV_CONFIG'} || "$config_directory/miniserv.conf",
	    $_[0]);
}

=head2 restart_miniserv([nowait], [ignore-errors])

Kill the old miniserv process and re-start it, then optionally waits for
it to restart. This will apply all configuration settings.

=cut
sub restart_miniserv
{
my ($nowait, $ignore) = @_;
return undef if (&is_readonly_mode());
my %miniserv;
&get_miniserv_config(\%miniserv) || return;
if ($main::webmin_script_type eq 'web' && !$ENV{"MINISERV_CONFIG"} &&
    !$ENV{'MINISERV_PID'}) {
	# Running under some web server other than miniserv, so do nothing
	return;
	}

my $i;
if ($gconfig{'os_type'} ne 'windows') {
	# On Unix systems, we can restart with a signal
	my ($pid, $addr, $i);
	$miniserv{'inetd'} && return;
	my @oldst = stat($miniserv{'pidfile'});
	$pid = $ENV{'MINISERV_PID'};
	if (!$pid || !kill(0, $pid)) {
		if (!open(PID, $miniserv{'pidfile'})) {
			print STDERR "PID file $miniserv{'pidfile'} does ",
				     "not exist\n" if (!$ignore);
			return;
			}
		chop($pid = <PID>);
		close(PID);
		if (!$pid) {
			print STDERR "Invalid PID file $miniserv{'pidfile'}\n"
				if (!$ignore);
			return;
			}
		if (!kill(0, $pid)) {
			print STDERR "PID $pid from file $miniserv{'pidfile'} ",
			             "is not valid\n" if (!$ignore);
			return;
			}
		}

	# Just signal miniserv to restart
	if (!&kill_logged('HUP', $pid)) {
		&error("Incorrect Webmin PID $pid") if (!$ignore);
		}

	# Wait till new PID is written, indicating a restart
	for($i=0; $i<60; $i++) {
		sleep(1);
		my @newst = stat($miniserv{'pidfile'});
		last if ($newst[9] != $oldst[9]);
		}
	$i < 60 || $ignore || &error("Webmin server did not write new PID file");

	## Totally kill the process and re-run it
	#$SIG{'TERM'} = 'IGNORE';
	#&kill_logged('TERM', $pid);
	#&system_logged("$config_directory/start >/dev/null 2>&1 </dev/null");
	}
else {
	# On Windows, we need to use the flag file
	open(TOUCH, ">$miniserv{'restartflag'}");
	close(TOUCH);
	}

if (!$nowait) {
	# Wait for miniserv to come back up
	my $addr = $miniserv{'bind'} || "127.0.0.1";
	my $ok = 0;
	for($i=0; $i<20; $i++) {
		my $err;
		sleep(1);
		&open_socket($addr, $miniserv{'port'}, STEST, \$err);
		close(STEST);
		last if (!$err && ++$ok >= 2);
		}
	$i < 20 || $ignore || &error("Failed to restart Webmin server!");
	}
}

=head2 reload_miniserv([ignore-errors])

Sends a USR1 signal to the miniserv process, telling it to read-read it's
configuration files. Not all changes will be applied though, such as the
IP addresses and ports to accept connections on.

=cut
sub reload_miniserv
{
my ($ignore) = @_;
return undef if (&is_readonly_mode());
my %miniserv;
&get_miniserv_config(\%miniserv) || return;
if ($main::webmin_script_type eq 'web' && !$ENV{"MINISERV_CONFIG"} &&
    !$ENV{'MINISERV_PID'}) {
	# Running under some web server other than miniserv, so do nothing
	return;
	}

if ($gconfig{'os_type'} ne 'windows') {
	# Send a USR1 signal to re-read the config
	my ($pid, $addr, $i);
	$miniserv{'inetd'} && return;
	$pid = $ENV{'MINISERV_PID'};
	if (!$pid || !kill(0, $pid)) {
		if (!open(PID, $miniserv{'pidfile'})) {
			print STDERR "PID file $miniserv{'pidfile'} does ",
				     "not exist\n" if (!$ignore);
			return;
			}
		chop($pid = <PID>);
		close(PID);
		if (!$pid) {
			print STDERR "Invalid PID file $miniserv{'pidfile'}\n"
				if (!$ignore);
			return;
			}
		if (!kill(0, $pid)) {
			print STDERR "PID $pid from file $miniserv{'pidfile'} ",
			             "is not valid\n" if (!$ignore);
			return;
			}
		}
	if (!&kill_logged('USR1', $pid)) {
		&error("Incorrect Webmin PID $pid") if (!$ignore);
		}

	# Make sure this didn't kill Webmin!
	sleep(1);
	if (!kill(0, $pid)) {
		print STDERR "USR1 signal killed Webmin - restarting\n"
			if (!$ignore);
		&system_logged("$config_directory/start >/dev/null 2>&1 </dev/null");
		}
	}
else {
	# On Windows, we need to use the flag file
	open(TOUCH, ">$miniserv{'reloadflag'}");
	close(TOUCH);
	}
}

=head2 check_os_support(&minfo, [os-type, os-version], [api-only])

Returns 1 if some module is supported on the current operating system, or the
OS supplies as parameters. The parameters are :

=item minfo - A hash ref of module information, as returned by get_module_info

=item os-type - The Webmin OS code to use instead of the system's real OS, such as redhat-linux

=item os-version - The Webmin OS version to use, such as 13.0

=item api-only - If set to 1, considers a module supported if it provides an API to other modules on this OS, even if the majority of its functionality is not supported.

=cut
sub check_os_support
{
my $oss = $_[0]->{'os_support'};
if ($_[3] && $oss && $_[0]->{'api_os_support'}) {
	# May provide usable API
	$oss .= " ".$_[0]->{'api_os_support'};
	}
if ($_[0]->{'nozone'} && &running_in_zone()) {
	# Not supported in a Solaris Zone
	return 0;
	}
if ($_[0]->{'novserver'} && &running_in_vserver()) {
	# Not supported in a Linux Vserver
	return 0;
	}
if ($_[0]->{'noopenvz'} && &running_in_openvz()) {
	# Not supported in an OpenVZ container
	return 0;
	}
return 1 if (!$oss || $oss eq '*');
my $osver = $_[2] || $gconfig{'os_version'};
my $ostype = $_[1] || $gconfig{'os_type'};
my $anyneg = 0;
while(1) {
	my ($os, $ver, $codes);
	my ($neg) = ($oss =~ s/^!//);	# starts with !
	$anyneg++ if ($neg);
	if ($oss =~ /^([^\/\s]+)\/([^\{\s]+)\{([^\}]*)\}\s*(.*)$/) {
		# OS/version{code}
		$os = $1; $ver = $2; $codes = $3; $oss = $4;
		}
	elsif ($oss =~ /^([^\/\s]+)\/([^\/\s]+)\s*(.*)$/) {
		# OS/version
		$os = $1; $ver = $2; $oss = $3;
		}
	elsif ($oss =~ /^([^\{\s]+)\{([^\}]*)\}\s*(.*)$/) {
		# OS/{code}
		$os = $1; $codes = $2; $oss = $3;
		}
	elsif ($oss =~ /^\{([^\}]*)\}\s*(.*)$/) {
		# {code}
		$codes = $1; $oss = $2;
		}
	elsif ($oss =~ /^(\S+)\s*(.*)$/) {
		# OS
		$os = $1; $oss = $2;
		}
	else { last; }
	next if ($os && !($os eq $ostype ||
			  $ostype =~ /^(\S+)-(\S+)$/ && $os eq "*-$2"));
	if ($ver =~ /^([0-9\.]+)\-([0-9\.]+)$/) {
		next if ($osver < $1 || $osver > $2);
		}
	elsif ($ver =~ /^([0-9\.]+)\-\*$/) {
		next if ($osver < $1);
		}
	elsif ($ver =~ /^\*\-([0-9\.]+)$/) {
		next if ($osver > $1);
		}
	elsif ($ver) {
		next if ($ver ne $osver);
		}
	next if ($codes && !eval $codes);
	return !$neg;
	}
return $anyneg;
}

=head2 http_download(host, port, page, destfile, [&error], [&callback], [sslmode], [user, pass], [timeout], [osdn-convert], [no-cache], [&headers])

Downloads data from a HTTP url to a local file or string. The parameters are :

=item host - The hostname part of the URL, such as www.google.com

=item port - The HTTP port number, such as 80

=item page - The filename part of the URL, like /index.html

=item destfile - The local file to save the URL data to, like /tmp/index.html. This can also be a scalar reference, in which case the data will be appended to that scalar.

=item error - If set to a scalar ref, the function will store any error message in this scalar and return 0 on failure, or 1 on success. If not set, it will simply call the error function if the download fails.

=item callback - If set to a function ref, it will be called after each block of data is received. This is typically set to \&progress_callback, for printing download progress.

=item sslmode - If set to 1, an HTTPS connection is used instead of HTTP.

=item user - If set, HTTP authentication is done with this username.

=item pass - The HTTP password to use with the username above.

=item timeout - A timeout in seconds to wait for the TCP connection to be established before failing.

=item osdn-convert - If set to 1, URL for downloads from sourceforge are converted to use an appropriate mirror site.

=item no-cache - If set to 1, Webmin's internal caching for this URL is disabled.

=item headers - If set to a hash ref of additional HTTP headers, they will be added to the request.

=cut
sub http_download
{
my ($host, $port, $page, $dest, $error, $cbfunc, $ssl, $user, $pass,
    $timeout, $osdn, $nocache, $headers) = @_;
if ($gconfig{'debug_what_net'}) {
	&webmin_debug_log('HTTP', "host=$host port=$port page=$page ssl=$ssl".
				  ($user ? " user=$user pass=$pass" : "").
				  (ref($dest) ? "" : " dest=$dest"));
	}
if ($osdn) {
	# Convert OSDN URL first
	my $prot = $ssl ? "https://" : "http://";
	my $portstr = $ssl && $port == 443 ||
			 !$ssl && $port == 80 ? "" : ":$port";
	($host, $port, $page, $ssl) = &parse_http_url(
		&convert_osdn_url($prot.$host.$portstr.$page));
	}

# Check if we already have cached the URL
my $url = ($ssl ? "https://" : "http://").$host.":".$port.$page;
my $cfile = &check_in_http_cache($url);
if ($cfile && !$nocache) {
	# Yes! Copy to dest file or variable
	&$cbfunc(6, $url) if ($cbfunc);
	if (ref($dest)) {
		&open_readfile(CACHEFILE, $cfile);
		local $/ = undef;
		$$dest = <CACHEFILE>;
		close(CACHEFILE);
		}
	else {
		&copy_source_dest($cfile, $dest);
		}
	return;
	}

# Build headers
my @headers;
push(@headers, [ "Host", $host ]);
push(@headers, [ "User-agent", "Webmin" ]);
push(@headers, [ "Accept-language", "en" ]);
if ($user) {
	my $auth = &encode_base64("$user:$pass");
	$auth =~ tr/\r\n//d;
	push(@headers, [ "Authorization", "Basic $auth" ]);
	}
foreach my $hname (keys %$headers) {
	push(@headers, [ $hname, $headers->{$hname} ]);
	}

# Actually download it
$main::download_timed_out = undef;
local $SIG{ALRM} = \&download_timeout;
$timeout = 60 if (!defined($timeout));
alarm($timeout) if ($timeout);
my $h = &make_http_connection($host, $port, $ssl, "GET", $page, \@headers);
alarm(0) if ($timeout);
$h = $main::download_timed_out if ($main::download_timed_out);
if (!ref($h)) {
	if ($error) { $$error = $h; return; }
	else { &error(&html_escape($h)); }
	}
&complete_http_download($h, $dest, $error, $cbfunc, $osdn, $host, $port,
			$headers, $ssl, $nocache, $timeout);
if ((!$error || !$$error) && !$nocache) {
	&write_to_http_cache($url, $dest);
	}
}

=head2 complete_http_download(handle, destfile, [&error], [&callback], [osdn], [oldhost], [oldport], [&send-headers], [old-ssl], [no-cache], [timeout])

Do a HTTP download, after the headers have been sent. For internal use only,
typically called by http_download.

=cut
sub complete_http_download
{
my ($h, $destfile, $error, $cbfunc, $osdn, $oldhost, $oldport, $headers,
    $oldssl, $nocache, $timeout) = @_;
local ($line, %header, @headers, $s);  # Kept local so that callback funcs
				       # can access them.

# read headers
$timeout = 60 if (!defined($timeout));
alarm($timeout) if ($timeout);
($line = &read_http_connection($h)) =~ tr/\r\n//d;
if ($line !~ /^HTTP\/1\..\s+(200|30[0-9]|400)(\s+|$)/) {
	alarm(0) if ($timeout);
	&close_http_connection($h);
	if ($error) { ${$error} = $line; return; }
	else { &error("Download failed : ".&html_escape($line)); }
	}
my $rcode = $1;
&$cbfunc(1, $rcode >= 300 && $rcode < 400 ? 1 : 0)
	if ($cbfunc);
while(1) {
	$line = &read_http_connection($h);
	$line =~ tr/\r\n//d;
	$line =~ /^(\S+):\s*(.*)$/ || last;
	$header{lc($1)} = $2;
	push(@headers, [ lc($1), $2 ]);
	}
alarm(0) if ($timeout);
if ($main::download_timed_out) {
	&close_http_connection($h);
	if ($error) { ${$error} = $main::download_timed_out; return 0; }
	else { &error($main::download_timed_out); }
	}
&$cbfunc(2, $header{'content-length'}) if ($cbfunc);
if ($rcode >= 300 && $rcode < 400) {
	# follow the redirect
	&$cbfunc(5, $header{'location'}) if ($cbfunc);
	my ($host, $port, $page, $ssl);
	if ($header{'location'} =~ /^(http|https):\/\/([^:]+):(\d+)(\/.*)?$/) {
		$ssl = $1 eq 'https' ? 1 : 0;
		$host = $2;
		$port = $3;
		$page = $4 || "/";
		}
	elsif ($header{'location'} =~ /^(http|https):\/\/([^:\/]+)(\/.*)?$/) {
		$ssl = $1 eq 'https' ? 1 : 0;
		$host = $2;
		$port = $ssl ? 443 : 80;
		$page = $3 || "/";
		}
	elsif ($header{'location'} =~ /^\// && $_[5]) {
		# Relative to same server
		$host = $_[5];
		$port = $_[6];
		$ssl = $_[8];
		$page = $header{'location'};
		}
	elsif ($header{'location'}) {
		# Assume relative to same dir .. not handled
		&close_http_connection($h);
		if ($error) { ${$error} = "Invalid Location header $header{'location'}"; return; }
		else { &error("Invalid Location header ".
			      &html_escape($header{'location'})); }
		}
	else {
		&close_http_connection($h);
		if ($error) { ${$error} = "Missing Location header"; return; }
		else { &error("Missing Location header"); }
		}
	my $params;
	($page, $params) = split(/\?/, $page);
	$page =~ s/ /%20/g;
	$page .= "?".$params if (defined($params));
	&http_download($host, $port, $page, $destfile, $error, $cbfunc, $ssl,
		       undef, undef, undef, $_[4], $_[9], $_[7]);
	}
else {
	# read data
	if (ref($destfile)) {
		# Append to a variable
		while(defined($buf = &read_http_connection($h, 1024))) {
			${$destfile} .= $buf;
			&$cbfunc(3, length(${$destfile})) if ($cbfunc);
			}
		}
	else {
		# Write to a file
		my $got = 0;
		if (!&open_tempfile(PFILE, ">$destfile", 1)) {
			&close_http_connection($h);
			if ($error) { ${$error} = "Failed to write to $destfile : $!"; return; }
			else { &error("Failed to write to ".&html_escape($destfile)." : ".&html_escape("$!")); }
			}
		binmode(PFILE);		# For windows
		while(defined($buf = &read_http_connection($h, 1024))) {
			&print_tempfile(PFILE, $buf);
			$got += length($buf);
			&$cbfunc(3, $got) if ($cbfunc);
			}
		&close_tempfile(PFILE);
		if ($header{'content-length'} &&
		    $got != $header{'content-length'}) {
			&close_http_connection($h);
			if ($error) { ${$error} = "Download incomplete"; return; }
			else { &error("Download incomplete"); }
			}
		}
	&$cbfunc(4) if ($cbfunc);
	}
&close_http_connection($h);
}


=head2 http_post(host, port, page, content, destfile, [&error], [&callback], [sslmode], [user, pass], [timeout], [osdn-convert], [no-cache], [&headers])

Posts data to an HTTP url and downloads the response to a local file or string. The parameters are :

=item host - The hostname part of the URL, such as www.google.com

=item port - The HTTP port number, such as 80

=item page - The filename part of the URL, like /index.html

=item content - The data to post

=item destfile - The local file to save the URL data to, like /tmp/index.html. This can also be a scalar reference, in which case the data will be appended to that scalar.

=item error - If set to a scalar ref, the function will store any error message in this scalar and return 0 on failure, or 1 on success. If not set, it will simply call the error function if the download fails.

=item callback - If set to a function ref, it will be called after each block of data is received. This is typically set to \&progress_callback, for printing download progress.

=item sslmode - If set to 1, an HTTPS connection is used instead of HTTP.

=item user - If set, HTTP authentication is done with this username.

=item pass - The HTTP password to use with the username above.

=item timeout - A timeout in seconds to wait for the TCP connection to be established before failing.

=item osdn-convert - If set to 1, URL for downloads from sourceforge are converted to use an appropriate mirror site.

=item no-cache - If set to 1, Webmin's internal caching for this URL is disabled.

=item headers - If set to a hash ref of additional HTTP headers, they will be added to the request.

=cut
sub http_post
{
my ($host, $port, $page, $content, $dest, $error, $cbfunc, $ssl, $user, $pass,
    $timeout, $osdn, $nocache, $headers) = @_;
if ($gconfig{'debug_what_net'}) {
	&webmin_debug_log('HTTP', "host=$host port=$port page=$page ssl=$ssl".
				  ($user ? " user=$user pass=$pass" : "").
				  (ref($dest) ? "" : " dest=$dest"));
	}
if ($osdn) {
	# Convert OSDN URL first
	my $prot = $ssl ? "https://" : "http://";
	my $portstr = $ssl && $port == 443 ||
			 !$ssl && $port == 80 ? "" : ":$port";
	($host, $port, $page, $ssl) = &parse_http_url(
		&convert_osdn_url($prot.$host.$portstr.$page));
	}

# Build headers
my @headers;
push(@headers, [ "Host", $host ]);
push(@headers, [ "User-agent", "Webmin" ]);
push(@headers, [ "Accept-language", "en" ]);
push(@headers, [ "Content-type", "application/x-www-form-urlencoded" ]);
if (defined($content)) {
	push(@headers, [ "Content-length", length($content) ]);
	}
if ($user) {
	my $auth = &encode_base64("$user:$pass");
	$auth =~ tr/\r\n//d;
	push(@headers, [ "Authorization", "Basic $auth" ]);
	}
foreach my $hname (keys %$headers) {
	push(@headers, [ $hname, $headers->{$hname} ]);
	}

# Actually download it
$main::download_timed_out = undef;
local $SIG{ALRM} = \&download_timeout;
$timeout = 60 if (!defined($timeout));
alarm($timeout) if ($timeout);
my $h = &make_http_connection($host, $port, $ssl, "POST", $page, \@headers);
alarm(0) if ($timeout);
$h = $main::download_timed_out if ($main::download_timed_out);
if (!ref($h)) {
	if ($error) { $$error = $h; return; }
	else { &error($h); }
	}
&write_http_connection($h, $content."\r\n");
&complete_http_download($h, $dest, $error, $cbfunc, $osdn, $host, $port,
			$headers, $ssl, $nocache);
}

=head2 ftp_download(host, file, destfile, [&error], [&callback], [user, pass], [port], [no-cache])

Download data from an FTP site to a local file. The parameters are :

=item host - FTP server hostname

=item file - File on the FTP server to download

=item destfile - File on the Webmin system to download data to

=item error - If set to a string ref, any error message is written into this string and the function returns 0 on failure, 1 on success. Otherwise, error is called on failure.

=item callback - If set to a function ref, it will be called after each block of data is received. This is typically set to \&progress_callback, for printing download progress.

=item user - Username to login to the FTP server as. If missing, Webmin will login as anonymous.

=item pass - Password for the username above.

=item port - FTP server port number, which defaults to 21 if not set.

=item no-cache - If set to 1, Webmin's internal caching for this URL is disabled.

=item timeout - Timeout for connections, defaults to 60s

=cut
sub ftp_download
{
my ($host, $file, $dest, $error, $cbfunc, $user, $pass, $port, $nocache, $timeout) = @_;
$port ||= 21;
$timeout = 60 if (!defined($timeout));
if ($gconfig{'debug_what_net'}) {
	&webmin_debug_log('FTP', "host=$host port=$port file=$file".
				 ($user ? " user=$user pass=$pass" : "").
				 (ref($dest) ? "" : " dest=$dest"));
	}
my ($buf, @n);
if (&is_readonly_mode()) {
	if ($error) {
		$$error = "FTP connections not allowed in readonly mode";
		return 0;
		}
	else {
		&error("FTP connections not allowed in readonly mode");
		}
	}

# Check if we already have cached the URL
my $url = "ftp://".$host.$file;
my $cfile = &check_in_http_cache($url);
if ($cfile && !$nocache) {
	# Yes! Copy to dest file or variable
	&$cbfunc(6, $url) if ($cbfunc);
	if (ref($dest)) {
		&open_readfile(CACHEFILE, $cfile);
		local $/ = undef;
		$$dest = <CACHEFILE>;
		close(CACHEFILE);
		}
	else {
		&copy_source_dest($cfile, $dest);
		}
	return;
	}

# Actually download it
$main::download_timed_out = undef;
local $SIG{ALRM} = \&download_timeout;
alarm($timeout) if ($timeout);
my $connected;
if ($gconfig{'ftp_proxy'} =~ /^http:\/\/(\S+):(\d+)/ && !&no_proxy($_[0])) {
	# download through http-style proxy
	my $error;
	if (&open_socket($1, $2, "SOCK", \$error)) {
		# Connected OK
		if ($main::download_timed_out) {
			alarm(0) if ($timeout);
			if ($error) {
				$$error = $main::download_timed_out;
				return 0;
				}
			else {
				&error($main::download_timed_out);
				}
			}
		my $esc = $file; $esc =~ s/ /%20/g;
		my $up = "${user}:${pass}\@" if ($user);
		my $portstr = $port == 21 ? "" : ":$port";
		print SOCK "GET ftp://${up}${host}${portstr}${esc} HTTP/1.0\r\n";
		print SOCK "User-agent: Webmin\r\n";
		if ($gconfig{'proxy_user'}) {
			my $auth = &encode_base64(
			   "$gconfig{'proxy_user'}:$gconfig{'proxy_pass'}");
			$auth =~ tr/\r\n//d;
			print SOCK "Proxy-Authorization: Basic $auth\r\n";
			}
		print SOCK "\r\n";
		&complete_http_download(
			{ 'fh' => "SOCK" }, $dest, $error, $cbfunc,
			undef, undef, undef, undef, 0, $nocache);
		$connected = 1;
		}
	elsif (!$gconfig{'proxy_fallback'}) {
		alarm(0) if ($timeout);
		if ($error) {
			$$error = $main::download_timed_out;
			return 0;
			}
		else {
			&error($main::download_timed_out);
			}
		}
	}

if (!$connected) {
	# connect to host and login with real FTP protocol
	&open_socket($host, $port, "SOCK", $_[3]) || return 0;
	alarm(0) if ($timeout);
	if ($main::download_timed_out) {
		if ($error) {
			$$error = $main::download_timed_out;
			return 0;
			}
		else {
			&error($main::download_timed_out);
			}
		}
	&ftp_command("", 2, $error) || return 0;
	if ($user) {
		# Login as supplied user
		my @urv = &ftp_command("USER $user", [ 2, 3 ], $error);
		@urv || return 0;
		if (int($urv[1]/100) == 3) {
			&ftp_command("PASS $pass", 2, $error) || return 0;
			}
		}
	else {
		# Login as anonymous
		my @urv = &ftp_command("USER anonymous", [ 2, 3 ], $error);
		@urv || return 0;
		if (int($urv[1]/100) == 3) {
			&ftp_command("PASS root\@".&get_system_hostname(), 2,
				     $error) || return 0;
			}
		}
	&$cbfunc(1, 0) if ($cbfunc);

	if ($file) {
		# get the file size and tell the callback
		&ftp_command("TYPE I", 2, $error) || return 0;
		my $size = &ftp_command("SIZE $file", 2, $error);
		defined($size) || return 0;
		if ($cbfunc) {
			&$cbfunc(2, int($size));
			}

		# are we using IPv6?
		my $v6 = !&to_ipaddress($host) &&
			 &to_ip6address($host);

		if ($v6) {
			# request the file over a EPSV port
			my $epsv = &ftp_command("EPSV", 2, $error);
			defined($epsv) || return 0;
			$epsv =~ /\|(\d+)\|/ || return 0;
			my $epsvport = $1;
			&open_socket($host, $epsvport, CON, $error) || return 0;
			}
		else {
			# request the file over a PASV connection
			my $pasv = &ftp_command("PASV", 2, $error);
			defined($pasv) || return 0;
			$pasv =~ /\(([0-9,]+)\)/ || return 0;
			@n = split(/,/ , $1);
			&open_socket("$n[0].$n[1].$n[2].$n[3]",
				$n[4]*256 + $n[5], "CON", $_[3]) || return 0;
			}
		&ftp_command("RETR $file", 1, $error) || return 0;

		# transfer data
		my $got = 0;
		&open_tempfile(PFILE, ">$dest", 1);
		while(read(CON, $buf, 1024) > 0) {
			&print_tempfile(PFILE, $buf);
			$got += length($buf);
			&$cbfunc(3, $got) if ($cbfunc);
			}
		&close_tempfile(PFILE);
		close(CON);
		if ($got != $size) {
			if ($error) {
				$$error = "Download incomplete";
				return 0;
				}
			else {
				&error("Download incomplete");
				}
			}
		&$cbfunc(4) if ($cbfunc);

		&ftp_command("", 2, $error) || return 0;
		}

	# finish off..
	&ftp_command("QUIT", 2, $error) || return 0;
	close(SOCK);
	}

&write_to_http_cache($url, $dest);
return 1;
}

=head2 ftp_upload(host, file, srcfile, [&error], [&callback], [user, pass], [port])

Upload data from a local file to an FTP site. The parameters are :

=item host - FTP server hostname

=item file - File on the FTP server to write to

=item srcfile - File on the Webmin system to upload data from

=item error - If set to a string ref, any error message is written into this string and the function returns 0 on failure, 1 on success. Otherwise, error is called on failure.

=item callback - If set to a function ref, it will be called after each block of data is received. This is typically set to \&progress_callback, for printing upload progress.

=item user - Username to login to the FTP server as. If missing, Webmin will login as anonymous.

=item pass - Password for the username above.

=item port - FTP server port number, which defaults to 21 if not set.

=cut
sub ftp_upload
{
my ($buf, @n);
my $cbfunc = $_[4];
if (&is_readonly_mode()) {
	if ($_[3]) { ${$_[3]} = "FTP connections not allowed in readonly mode";
		     return 0; }
	else { &error("FTP connections not allowed in readonly mode"); }
	}

$main::download_timed_out = undef;
local $SIG{ALRM} = \&download_timeout;
alarm(60);

# connect to host and login
&open_socket($_[0], $_[7] || 21, "SOCK", $_[3]) || return 0;
alarm(0);
if ($main::download_timed_out) {
	if ($_[3]) { ${$_[3]} = $main::download_timed_out; return 0; }
	else { &error($main::download_timed_out); }
	}
&ftp_command("", 2, $_[3]) || return 0;
if ($_[5]) {
	# Login as supplied user
	my @urv = &ftp_command("USER $_[5]", [ 2, 3 ], $_[3]);
	@urv || return 0;
	if (int($urv[1]/100) == 3) {
		if (!&ftp_command("PASS $_[6]", 2, $_[3])) {
			${$_[3]} =~ s/PASS\s+\S+/PASS \*\*\*\*\*/ if ($_[3]);
			return 0;
			}
		}
	}
else {
	# Login as anonymous
	my @urv = &ftp_command("USER anonymous", [ 2, 3 ], $_[3]);
	@urv || return 0;
	if (int($urv[1]/100) == 3) {
		if (!&ftp_command("PASS root\@".&get_system_hostname(), 2,
				  $_[3])) {
			${$_[3]} =~ s/PASS\s+\S+/PASS \*\*\*\*\*/ if ($_[3]);
			return 0;
			}
		}
	}
&$cbfunc(1, 0) if ($cbfunc);

&ftp_command("TYPE I", 2, $_[3]) || return 0;

# get the file size and tell the callback
my @st = stat($_[2]);
if ($cbfunc) {
	&$cbfunc(2, $st[7]);
	}

# are we using IPv6?
my $v6 = !&to_ipaddress($_[0]) && &to_ip6address($_[0]);

if ($v6) {
	# send the file over a EPSV port
	my $epsv = &ftp_command("EPSV", 2, $_[3]);
	defined($epsv) || return 0;
	$epsv =~ /\|(\d+)\|/ || return 0;
	my $epsvport = $1;
	&open_socket($_[0], $epsvport, "CON", $_[3]) || return 0;
	}
else {
	# send the file over a PASV connection
	my $pasv = &ftp_command("PASV", 2, $_[3]);
	defined($pasv) || return 0;
	$pasv =~ /\(([0-9,]+)\)/ || return 0;
	@n = split(/,/ , $1);
	&open_socket("$n[0].$n[1].$n[2].$n[3]", $n[4]*256 + $n[5], "CON", $_[3]) || return 0;
	}
&ftp_command("STOR $_[1]", 1, $_[3]) || return 0;

# transfer data
my $got;
open(PFILE, $_[2]);
while(read(PFILE, $buf, 1024) > 0) {
	print CON $buf;
	$got += length($buf);
	&$cbfunc(3, $got) if ($cbfunc);
	}
close(PFILE);
close(CON);
if ($got != $st[7]) {
	if ($_[3]) { ${$_[3]} = "Upload incomplete"; return 0; }
	else { &error("Upload incomplete"); }
	}
&$cbfunc(4) if ($cbfunc);

# finish off..
&ftp_command("", 2, $_[3]) || return 0;
&ftp_command("QUIT", 2, $_[3]) || return 0;
close(SOCK);

return 1;
}

=head2 no_proxy(host)

Checks if some host is on the no proxy list. For internal use by the
http_download and ftp_download functions.

=cut
sub no_proxy
{
my $ip = &to_ipaddress($_[0]);
foreach my $n (split(/\s+/, $gconfig{'noproxy'})) {
	return 1 if ($_[0] =~ /\Q$n\E/ ||
		     $ip =~ /\Q$n\E/);
	}
return 0;
}

=head2 open_socket(host, port, handle, [&error])

Open a TCP connection to some host and port, using a file handle. The
parameters are :

=item host - Hostname or IP address to connect to.

=item port - TCP port number.

=item handle - A file handle name to use for the connection.

=item error - A string reference to write any error message into. If not set, the error function is called on failure.

=item bindip - Local IP address to bind to for outgoing connections

=cut
sub open_socket
{
my ($host, $port, $fh, $err, $bindip) = @_;
$fh = &callers_package($fh);
$bindip ||= $gconfig{'bind_proxy'};

if ($gconfig{'debug_what_net'}) {
	&webmin_debug_log('TCP', "host=$host port=$port");
	}

# Lookup IP address for the host. Try v4 first, and failing that v6
my $ip;
my $proto = getprotobyname("tcp");
if ($ip = &to_ipaddress($host)) {
	# Create IPv4 socket and connection
	if (!socket($fh, PF_INET(), SOCK_STREAM, $proto)) {
		my $msg = "Failed to create socket : $!";
		if ($err) { $$err = $msg; return 0; }
		else { &error($msg); }
		}
	my $addr = inet_aton($ip);
	if ($gconfig{'bind_proxy'}) {
		# BIND to outgoing IP
		if (!bind($fh, pack_sockaddr_in(0, inet_aton($bindip)))) {
			my $msg = "Failed to bind to source address : $!";
			if ($err) { $$err = $msg; return 0; }
			else { &error($msg); }
			}
		}
	if (!connect($fh, pack_sockaddr_in($port, $addr))) {
		my $msg = "Failed to connect to $host:$port : $!";
		if ($err) { $$err = $msg; return 0; }
		else { &error($msg); }
		}
	}
elsif ($ip = &to_ip6address($host)) {
	# Create IPv6 socket and connection
	if (!&supports_ipv6()) {
		$msg = "IPv6 connections are not supported";
		if ($err) { $$err = $msg; return 0; }
		else { &error($msg); }
		}
	if (!socket($fh, PF_INET6(), SOCK_STREAM, $proto)) {
		my $msg = "Failed to create IPv6 socket : $!";
		if ($err) { $$err = $msg; return 0; }
		else { &error($msg); }
		}
	my $addr = inet_pton(AF_INET6(), $ip);
	if (!connect($fh, pack_sockaddr_in6($port, $addr))) {
		my $msg = "Failed to IPv6 connect to $host:$port : $!";
		if ($err) { $$err = $msg; return 0; }
		else { &error($msg); }
		}
	}
else {
	# Resolution failed
	my $msg = "Failed to lookup IP address for $host";
	if ($err) { $$err = $msg; return 0; }
	else { &error($msg); }
	}

# Disable buffering
my $old = select($fh);
$| = 1;
select($old);
return 1;
}

=head2 download_timeout

Called when a download times out. For internal use only.

=cut
sub download_timeout
{
$main::download_timed_out = "Download timed out";
}

=head2 ftp_command(command, expected, [&error], [filehandle])

Send an FTP command, and die if the reply is not what was expected. Mainly
for internal use by the ftp_download and ftp_upload functions.

=cut
sub ftp_command
{
my ($cmd, $expect, $err, $fh) = @_;
$fh ||= "SOCK";
$fh = &callers_package($fh);

my $line;
my $what = $cmd ne "" ? "<i>$cmd</i>" : "initial connection";
if ($cmd ne "") {
        print $fh "$cmd\r\n";
        }
alarm(60);
if (!($line = <$fh>)) {
	alarm(0);
	if ($err) { $$err = "Failed to read reply to $what"; return undef; }
	else { &error("Failed to read reply to $what"); }
        }
$line =~ /^(...)(.)(.*)$/;
my $found = 0;
if (ref($expect)) {
	foreach my $c (@$expect) {
		$found++ if (int($1/100) == $c);
		}
	}
else {
	$found++ if (int($1/100) == $_[1]);
	}
if (!$found) {
	alarm(0);
	if ($err) { $$err = "$what failed : $3"; return undef; }
	else { &error("$what failed : $3"); }
	}
my $rcode = $1;
my $reply = $3;
if ($2 eq "-") {
        # Need to skip extra stuff..
        while(1) {
                if (!($line = <$fh>)) {
			alarm(0);
			if ($err) { $$err = "Failed to read reply to $what";
				     return undef; }
			else { &error("Failed to read reply to $what"); }
                        }
                $line =~ /^(....)(.*)$/; $reply .= $2;
		if ($1 eq "$rcode ") { last; }
                }
        }
alarm(0);
return wantarray ? ($reply, $rcode) : $reply;
}

=head2 to_ipaddress(hostname)

Converts a hostname to an a.b.c.d format IP address, or returns undef if
it cannot be resolved.

=cut
sub to_ipaddress
{
if (&check_ipaddress($_[0])) {
	return $_[0];	# Already in v4 format
	}
elsif (&check_ip6address($_[0])) {
	return undef;	# A v6 address cannot be converted to v4
	}
else {
	my $hn = gethostbyname($_[0]);
	return undef if (!$hn);
	local @ip = unpack("CCCC", $hn);
	return join("." , @ip);
	}
}

=head2 to_ip6address(hostname)

Converts a hostname to IPv6 address, or returns undef if it cannot be resolved.

=cut
sub to_ip6address
{
if (&check_ip6address($_[0])) {
	return $_[0];	# Already in v6 format
	}
elsif (&check_ipaddress($_[0])) {
	return undef;	# A v4 address cannot be v6
	}
elsif (!&supports_ipv6()) {
	return undef;	# Cannot lookup
	}
else {
	# Perform IPv6 DNS lookup
	my $inaddr;
	(undef, undef, undef, $inaddr) =
	    getaddrinfo($_[0], undef, AF_INET6(), SOCK_STREAM);
	return undef if (!$inaddr);
	my $addr;
	(undef, $addr) = unpack_sockaddr_in6($inaddr);
	return inet_ntop(AF_INET6(), $addr);
	}
}

=head2 to_hostname(ipv4|ipv6-address)

Reverse-resolves an IPv4 or 6 address to a hostname

=cut
sub to_hostname
{
my ($addr) = @_;
if (&check_ip6address($addr) && &supports_ipv6()) {
	return gethostbyaddr(inet_pton(AF_INET6(), $addr), AF_INET6());
	}
else {
	return gethostbyaddr(inet_aton($addr), AF_INET);
	}
}

=head2 icons_table(&links, &titles, &icons, [columns], [href], [width], [height], &befores, &afters)

Renders a 4-column table of icons. The useful parameters are :

=item links - An array ref of link destination URLs for the icons.

=item titles - An array ref of titles to appear under the icons.

=item icons - An array ref of URLs for icon images.

=item columns - Number of columns to layout the icons with. Defaults to 4.

=cut
sub icons_table
{
&load_theme_library();
if (defined(&theme_icons_table)) {
	&theme_icons_table(@_);
	return;
	}
my $need_tr;
my $cols = $_[3] ? $_[3] : 4;
my $per = int(100.0 / $cols);
print "<table class='icons_table' width='100%' cellpadding='5'>\n";
for(my $i=0; $i<@{$_[0]}; $i++) {
	if ($i%$cols == 0) { print "<tr>\n"; }
	print "<td width='$per%' align='center' valign='top'>\n";
	&generate_icon($_[2]->[$i], $_[1]->[$i], $_[0]->[$i],
		       ref($_[4]) ? $_[4]->[$i] : $_[4], $_[5], $_[6],
		       $_[7]->[$i], $_[8]->[$i]);
	print "</td>\n";
        if ($i%$cols == $cols-1) { print "</tr>\n"; }
        }
while($i++%$cols) { print "<td width='$per%'></td>\n"; $need_tr++; }
print "</tr>\n" if ($need_tr);
print "</table>\n";
}

=head2 replace_meta($string)

Replaces all occurrences of meta words

=item string - String value to search/replace in

=cut
sub replace_meta
{
  my ($string) = @_;

  my $hostname   = &get_display_hostname();
  my $version    = &get_webmin_version();
  my $os_type    = $gconfig{'real_os_type'} || $gconfig{'os_type'};
  my $os_version = $gconfig{'real_os_version'} || $gconfig{'os_version'};
  $string =~ s/%HOSTNAME%/$hostname/g;
  $string =~ s/%VERSION%/$version/g;
  $string =~ s/%USER%/$remote_user/g;
  $string =~ s/%OS%/$os_type $os_version/g;

  return $string;
}

=head2 replace_file_line(file, line, [newline]*)

Replaces one line in some file with 0 or more new lines. The parameters are :

=item file - Full path to some file, like /etc/hosts.

=item line - Line number to replace, starting from 0.

=item newline - Zero or more lines to put into the file at the given line number. These must be newline-terminated strings.

=cut
sub replace_file_line
{
my @lines;
my $realfile = &translate_filename($_[0]);
open(FILE, $realfile);
@lines = <FILE>;
close(FILE);
if (@_ > 2) { splice(@lines, $_[1], 1, @_[2..$#_]); }
else { splice(@lines, $_[1], 1); }
&open_tempfile(FILE, ">$realfile");
&print_tempfile(FILE, @lines);
&close_tempfile(FILE);
}

=head2 read_file_lines(file, [readonly])

Returns a reference to an array containing the lines from some file. This
array can be modified, and will be written out when flush_file_lines()
is called. The parameters are :

=item file - Full path to the file to read.

=item readonly - Should be set 1 if the caller is only going to read the lines, and never write it out.

Example code :

 $lref = read_file_lines("/etc/hosts");
 push(@$lref, "127.0.0.1 localhost");
 flush_file_lines("/etc/hosts");

=cut
sub read_file_lines
{
my ($file, $readonly) = @_;
if (!$file) {
	my ($package, $filename, $line) = caller;
	&error("Missing file to read at ${package}::${filename} line $line");
	}
my $realfile = &translate_filename($file);
if (!$main::file_cache{$realfile}) {
        my (@lines, $eol);
	local $_;
	&webmin_debug_log('READ', $file) if ($gconfig{'debug_what_read'});
        open(READFILE, $realfile);
        while(<READFILE>) {
		if (!$eol) {
			$eol = /\r\n$/ ? "\r\n" : "\n";
			}
                tr/\r\n//d;
                push(@lines, $_);
                }
        close(READFILE);
        $main::file_cache{$realfile} = \@lines;
	$main::file_cache_noflush{$realfile} = $readonly;
	$main::file_cache_eol{$realfile} = $eol || "\n";
        }
else {
	# Make read-write if currently readonly
	if (!$readonly) {
		$main::file_cache_noflush{$realfile} = 0;
		}
	}
return $main::file_cache{$realfile};
}

=head2 flush_file_lines([file], [eol], [ignore-unloaded])

Write out to a file previously read by read_file_lines to disk (except
for those marked readonly). The parameters are :

=item file - The file to flush out.

=item eof - End-of-line character for each line. Defaults to \n.

=item ignore-unloaded - Don't fail if the file isn't loaded

=cut
sub flush_file_lines
{
my ($file, $eof, $ignore) = @_;
my @files;
if ($file) {
	local $trans = &translate_filename($file);
	if (!$main::file_cache{$trans}) {
		if ($ignore) {
			return 0;
			}
		else {
			&error("flush_file_lines called on non-loaded file $trans");
			}
		}
	push(@files, $trans);
	}
else {
	@files = ( keys %main::file_cache );
	}
foreach my $f (@files) {
	my $eol = $eof || $main::file_cache_eol{$f} || "\n";
	if (!$main::file_cache_noflush{$f}) {
		no warnings; # XXX Bareword file handles should go away
		&open_tempfile(FLUSHFILE, ">$f");
		foreach my $line (@{$main::file_cache{$f}}) {
			(print FLUSHFILE $line,$eol) ||
				&error(&text("efilewrite", $f, $!));
			}
		&close_tempfile(FLUSHFILE);
		}
	delete($main::file_cache{$f});
	delete($main::file_cache_noflush{$f});
        }
return scalar(@files);
}

=head2 unflush_file_lines(file)

Clear the internal cache of some given file, previously read by read_file_lines.

=cut
sub unflush_file_lines
{
my $realfile = &translate_filename($_[0]);
delete($main::file_cache{$realfile});
delete($main::file_cache_noflush{$realfile});
}

=head2 unix_user_input(fieldname, user, [form])

Returns HTML for an input to select a Unix user. By default this is a text
box with a user popup button next to it.

=cut
sub unix_user_input
{
if (defined(&theme_unix_user_input)) {
	return &theme_unix_user_input(@_);
	}
return "<input name=$_[0] size=13 value=\"$_[1]\"> ".
       &user_chooser_button($_[0], 0, $_[2] || 0)."\n";
}

=head2 unix_group_input(fieldname, user, [form])

Returns HTML for an input to select a Unix group. By default this is a text
box with a group popup button next to it.

=cut
sub unix_group_input
{
if (defined(&theme_unix_group_input)) {
	return &theme_unix_group_input(@_);
	}
return "<input name='$_[0]' size=13 value=\"$_[1]\"> ".
       &group_chooser_button($_[0], 0, $_[2] || 0)."\n";
}

=head2 hlink(text, page, [module], [width], [height])

Returns HTML for a link that when clicked on pops up a window for a Webmin
help page. The parameters are :

=item text - Text for the link.

=item page - Help page code, such as 'intro'.

=item module - Module the help page is in. Defaults to the current module.

=item width - Width of the help popup window. Defaults to 600 pixels.

=item height - Height of the help popup window. Defaults to 400 pixels.

The actual help pages are in each module's help sub-directory, in files with
.html extensions.

=cut
sub hlink
{
if (defined(&theme_hlink)) {
	return &theme_hlink(@_);
	}
my $mod = $_[2] ? $_[2] : &get_module_name();
my $width = $_[3] || $tconfig{'help_width'} || $gconfig{'help_width'} || 600;
my $height = $_[4] || $tconfig{'help_height'} || $gconfig{'help_height'} || 400;
return "<a onClick='window.open(\"$gconfig{'webprefix'}/help.cgi/$mod/$_[1]\", \"help\", \"toolbar=no,menubar=no,scrollbars=yes,width=$width,height=$height,resizable=yes\"); return false' href=\"$gconfig{'webprefix'}/help.cgi/$mod/$_[1]\">$_[0]</a>";
}

=head2 user_chooser_button(field, multiple, [form])

Returns HTML for a javascript button for choosing a Unix user or users.
The parameters are :

=item field - Name of the HTML field to place the username into.

=item multiple - Set to 1 if multiple users can be selected.

=item form - Index of the form on the page.

=cut
sub user_chooser_button
{
return undef if (!&supports_users());
return &theme_user_chooser_button(@_)
	if (defined(&theme_user_chooser_button));
my $form = defined($_[2]) ? $_[2] : 0;
my $w = $_[1] ? 500 : 300;
my $h = 200;
if ($_[1] && $gconfig{'db_sizeusers'}) {
	($w, $h) = split(/x/, $gconfig{'db_sizeusers'});
	}
elsif (!$_[1] && $gconfig{'db_sizeuser'}) {
	($w, $h) = split(/x/, $gconfig{'db_sizeuser'});
	}
return "<input type=button onClick='ifield = form.$_[0]; chooser = window.open(\"$gconfig{'webprefix'}/user_chooser.cgi?multi=$_[1]&user=\"+escape(ifield.value), \"chooser\", \"toolbar=no,menubar=no,scrollbars=yes,resizable=yes,width=$w,height=$h\"); chooser.ifield = ifield; window.ifield = ifield' value=\"...\">\n";
}

=head2 group_chooser_button(field, multiple, [form])

Returns HTML for a javascript button for choosing a Unix group or groups
The parameters are :

=item field - Name of the HTML field to place the group name into.

=item multiple - Set to 1 if multiple groups can be selected.

=item form - Index of the form on the page.

=cut
sub group_chooser_button
{
return undef if (!&supports_users());
return &theme_group_chooser_button(@_)
	if (defined(&theme_group_chooser_button));
my $form = defined($_[2]) ? $_[2] : 0;
my $w = $_[1] ? 500 : 300;
my $h = 200;
if ($_[1] && $gconfig{'db_sizeusers'}) {
	($w, $h) = split(/x/, $gconfig{'db_sizeusers'});
	}
elsif (!$_[1] && $gconfig{'db_sizeuser'}) {
	($w, $h) = split(/x/, $gconfig{'db_sizeuser'});
	}
return "<input type=button onClick='ifield = form.$_[0]; chooser = window.open(\"$gconfig{'webprefix'}/group_chooser.cgi?multi=$_[1]&group=\"+escape(ifield.value), \"chooser\", \"toolbar=no,menubar=no,scrollbars=yes,resizable=yes,width=$w,height=$h\"); chooser.ifield = ifield; window.ifield = ifield' value=\"...\">\n";
}

=head2 foreign_check(module, [api-only])

Checks if some other module exists and is supported on this OS. The parameters
are :

=item module - Name of the module to check.

=item api-only - Set to 1 if you just want to check if the module provides an API that others can call, instead of the full web UI.

=cut
sub foreign_check
{
my ($mod, $api) = @_;
my %minfo;
my $mdir = &module_root_directory($mod);
&read_file_cached("$mdir/module.info", \%minfo) || return 0;
return &check_os_support(\%minfo, undef, undef, $api);
}

=head2 foreign_exists(module)

Checks if some other module exists. The module parameter is the short module
name.

=cut
sub foreign_exists
{
my $mdir = &module_root_directory($_[0]);
return -r "$mdir/module.info";
}

=head2 foreign_available(module)

Returns 1 if some module is installed, and acessible to the current user. The
module parameter is the module directory name.

=cut
sub foreign_available
{
return 0 if (!&foreign_check($_[0]) &&
	     !$gconfig{'available_even_if_no_support'});
my %foreign_module_info = &get_module_info($_[0]);

# Check list of allowed modules
my %acl;
&read_acl(\%acl, undef, [ $base_remote_user ]);
return 0 if (!$acl{$base_remote_user,$_[0]} &&
	     !$acl{$base_remote_user,'*'});

# Check for usermod restrictions
my @usermods = &list_usermods();
return 0 if (!&available_usermods( [ \%foreign_module_info ], \@usermods));

if (&get_product_name() eq "webmin") {
	# Check if the user has any RBAC privileges in this module
	if (&supports_rbac($_[0]) &&
	    &use_rbac_module_acl(undef, $_[0])) {
		# RBAC is enabled for this user and module - check if he
		# has any rights
		my $rbacs = &get_rbac_module_acl($remote_user, $_[0]);
		return 0 if (!$rbacs);
		}
	elsif ($gconfig{'rbacdeny_'.$base_remote_user}) {
		# If denying access to modules not specifically allowed by
		# RBAC, then prevent access
		return 0;
		}
	}

# Check readonly support
if (&is_readonly_mode()) {
	return 0 if (!$foreign_module_info{'readonly'});
	}

# Check if theme vetos
if (defined(&theme_foreign_available)) {
	return 0 if (!&theme_foreign_available($_[0]));
	}

# Check if licence module vetos
if ($main::licence_module) {
	return 0 if (!&foreign_call($main::licence_module,
				    "check_module_licence", $_[0]));
	}

return 1;
}

=head2 foreign_require(module, [file], [package])

Brings in functions from another module, and places them in the Perl namespace
with the same name as the module. The parameters are :

=item module - The source module's directory name, like sendmail.

=item file - The API file in that module, like sendmail-lib.pl. If missing, all API files are loaded.

=item package - Perl package to place the module's functions and global variables in.

If the original module name contains dashes, they will be replaced with _ in
the package name.

=cut
sub foreign_require
{
my ($mod, $file, $pkg) = @_;
$pkg ||= $mod || "global";
$pkg =~ s/[^A-Za-z0-9]/_/g;
my @files;
if ($file) {
	push(@files, $file);
	}
else {
	# Auto-detect files
	my %minfo = &get_module_info($mod);
	if ($minfo{'library'}) {
		@files = split(/\s+/, $minfo{'library'});
		}
	else {
		@files = ( ($minfo{'cloneof'} || $mod)."-lib.pl" );
		}
	}
@files = grep { !$main::done_foreign_require{$pkg,$_} } @files;
return 1 if (!@files);
foreach my $f (@files) {
	$main::done_foreign_require{$pkg,$f}++;
	}
my @OLDINC = @INC;
my $mdir = &module_root_directory($mod);
$mdir =~ /^(.*)$/; # untaint, part 1
$mdir = $1; 	   # untaint, part 2
@INC = &unique($mdir, @INC);
-d $mdir || &error("Module $mod does not exist");
if (!&get_module_name() && $mod) {
	chdir($mdir);
	}
my $old_fmn = $ENV{'FOREIGN_MODULE_NAME'};
my $old_frd = $ENV{'FOREIGN_ROOT_DIRECTORY'};
my $code = "package $pkg; ".
	   "\$ENV{'FOREIGN_MODULE_NAME'} = '$mod'; ".
	   "\$ENV{'FOREIGN_ROOT_DIRECTORY'} = '$root_directory'; ";
foreach my $f (@files) {
	$code .= "do '$mdir/$f' || die \$@; ";
	}
eval $code;
if (defined($old_fmn)) {
	$ENV{'FOREIGN_MODULE_NAME'} = $old_fmn;
	}
else {
	delete($ENV{'FOREIGN_MODULE_NAME'});
	}
if (defined($old_frd)) {
	$ENV{'FOREIGN_ROOT_DIRECTORY'} = $old_frd;
	}
else {
	delete($ENV{'FOREIGN_ROOT_DIRECTORY'});
	}
@INC = @OLDINC;
if ($@) { &error("Require $mod/$files[0] failed : <pre>$@</pre>"); }
return 1;
}

=head2 foreign_call(module, function, [arg]*)

Call a function in another module. The module parameter is the target module
directory name, function is the perl sub to call, and the remaining parameters
are the arguments. However, unless you need to call a function whose name
is dynamic, it is better to use Perl's cross-module function call syntax
like module::function(args).

=cut
sub foreign_call
{
my $pkg = $_[0] || "global";
$pkg =~ s/[^A-Za-z0-9]/_/g;
my @args = @_[2 .. @_-1];
$main::foreign_args = \@args;
my @rv = eval <<EOF;
package $pkg;
&$_[1](\@{\$main::foreign_args});
EOF
if ($@) { &error("$_[0]::$_[1] failed : $@"); }
return wantarray ? @rv : $rv[0];
}

=head2 foreign_config(module, [user-config])

Get the configuration from another module, and return it as a hash. If the
user-config parameter is set to 1, returns the Usermin user-level preferences
for the current user instead.

=cut
sub foreign_config
{
my ($mod, $uc) = @_;
my %fconfig;
if ($uc) {
	&read_file_cached("$root_directory/$mod/defaultuconfig", \%fconfig);
	&read_file_cached("$config_directory/$mod/uconfig", \%fconfig);
	&read_file_cached("$user_config_directory/$mod/config", \%fconfig);
	}
else {
	&read_file_cached("$config_directory/$mod/config", \%fconfig);
	}
return %fconfig;
}

=head2 foreign_installed(module, mode)

Checks if the server for some module is installed, and possibly also checks
if the module has been configured by Webmin.
For mode 1, returns 2 if the server is installed and configured for use by
Webmin, 1 if installed but not configured, or 0 otherwise.
For mode 0, returns 1 if installed, 0 if not.
If the module does not provide an install_check.pl script, assumes that
the server is installed.

=cut
sub foreign_installed
{
my ($mod, $configured) = @_;
if (defined($main::foreign_installed_cache{$mod,$configured})) {
	# Already cached..
	return $main::foreign_installed_cache{$mod,$configured};
	}
else {
	my $rv;
	if (!&foreign_check($mod)) {
		# Module is missing
		$rv = 0;
		}
	else {
		my $mdir = &module_root_directory($mod);
		if (!-r "$mdir/install_check.pl") {
			# Not known, assume OK
			$rv = $configured ? 2 : 1;
			}
		else {
			# Call function to check
			&foreign_require($mod, "install_check.pl");
			$rv = &foreign_call($mod, "is_installed", $configured);
			}
		}
	$main::foreign_installed_cache{$mod,$configured} = $rv;
	return $rv;
	}
}

=head2 foreign_defined(module, function)

Returns 1 if some function is defined in another module. In general, it is
simpler to use the syntax &defined(module::function) instead.

=cut
sub foreign_defined
{
my ($pkg) = @_;
$pkg =~ s/[^A-Za-z0-9]/_/g;
my $func = "${pkg}::$_[1]";
return defined(&$func);
}

=head2 get_system_hostname([short], [skip-file])

Returns the hostname of this system. If the short parameter is set to 1,
then the domain name is not prepended - otherwise, Webmin will attempt to get
the fully qualified hostname, like foo.example.com.

=cut
sub get_system_hostname
{
my $m = int($_[0]);
my $skipfile = $_[1];
if (!$main::get_system_hostname[$m]) {
	if ($gconfig{'os_type'} ne 'windows') {
		# Try some common Linux hostname files first
		my $fromfile;
		if ($skipfile) {
			# Never get from file
			}
		elsif ($gconfig{'os_type'} eq 'redhat-linux') {
			my %nc;
			&read_env_file("/etc/sysconfig/network", \%nc);
			if ($nc{'HOSTNAME'}) {
				$fromfile = $nc{'HOSTNAME'};
				}
			}
		elsif ($gconfig{'os_type'} eq 'debian-linux') {
			my $hn = &read_file_contents("/etc/hostname");
			if ($hn) {
				$hn =~ s/\r|\n//g;
				$fromfile = $hn;
				}
			}
		elsif ($gconfig{'os_type'} eq 'open-linux') {
			my $hn = &read_file_contents("/etc/HOSTNAME");
			if ($hn) {
				$hn =~ s/\r|\n//g;
				$fromfile = $hn;
				}
			}
		elsif ($gconfig{'os_type'} eq 'solaris') {
			my $hn = &read_file_contents("/etc/nodename");
			if ($hn) {
				$hn =~ s/\r|\n//g;
				$fromfile = $hn;
				}
			}

		# If we found a hostname in a file, use it
		if ($fromfile && ($m || $fromfile =~ /\./)) {
			if ($m) {
				$fromfile =~ s/\..*$//;
				}
			$main::get_system_hostname[$m] = $fromfile;
			return $fromfile;
			}

		# Can use hostname command on Unix
		&execute_command("hostname", undef,
				 \$main::get_system_hostname[$m], undef, 0, 1);
		chop($main::get_system_hostname[$m]);
		if ($?) {
			eval "use Sys::Hostname";
			if (!$@) {
				$main::get_system_hostname[$m] = eval "hostname()";
				}
			if ($@ || !$main::get_system_hostname[$m]) {
				$main::get_system_hostname[$m] = "UNKNOWN";
				}
			}
		elsif ($main::get_system_hostname[$m] !~ /\./ &&
		       $gconfig{'os_type'} =~ /linux$/ &&
		       !$gconfig{'no_hostname_f'} && !$_[0]) {
			# Try with -f flag to get fully qualified name
			my $flag;
			my $ex = &execute_command("hostname -f", undef, \$flag,
						  undef, 0, 1);
			chop($flag);
			if ($ex || $flag eq "") {
				# -f not supported! We have probably set the
				# hostname to just '-f'. Fix the problem
				# (if we are root)
				if ($< == 0) {
					&execute_command("hostname ".
						quotemeta($main::get_system_hostname[$m]),
						undef, undef, undef, 0, 1);
					}
				}
			else {
				$main::get_system_hostname[$m] = $flag;
				}
			}
		}
	else {
		# On Windows, try computername environment variable
		return $ENV{'computername'} if ($ENV{'computername'});
		return $ENV{'COMPUTERNAME'} if ($ENV{'COMPUTERNAME'});

		# Fall back to net name command
		my $out = `net name 2>&1`;
		if ($out =~ /\-+\r?\n(\S+)/) {
			$main::get_system_hostname[$m] = $1;
			}
		else {
			$main::get_system_hostname[$m] = "windows";
			}
		}
	}
return $main::get_system_hostname[$m];
}

=head2 get_webmin_version

Returns the version of Webmin currently being run, such as 1.450.

=cut
sub get_webmin_version
{
if (!$get_webmin_version) {
	open(VERSION, "$root_directory/version") || return 0;
	($get_webmin_version = <VERSION>) =~ tr/\r|\n//d;
	close(VERSION);
	if (length($get_webmin_version) > 6) {
		$get_webmin_version_ui = substr($get_webmin_version, 0, 5) . "." . substr($get_webmin_version, 5, 5 - 1) . "." . substr($get_webmin_version, 5 * 2 - 1);
		}
	}
if ($main::webmin_script_type eq 'web' && $get_webmin_version_ui) {
	return $get_webmin_version_ui;
	}
else {
	return $get_webmin_version;
	}
}

=head2 get_module_acl([user], [module], [no-rbac], [no-default])

Returns a hash containing access control options for the given user and module.
By default the current username and module name are used. If the no-rbac flag
is given, the permissions will not be updated based on the user's RBAC role
(as seen on Solaris). If the no-default flag is given, default permissions for
the module will not be included.

=cut
sub get_module_acl
{
my $u = defined($_[0]) ? $_[0] : $base_remote_user;
my $m = defined($_[1]) ? $_[1] : &get_module_name();
$m ||= "";
my $mdir = &module_root_directory($m);
my %rv;
if (!$_[3]) {
	# Read default ACL first, to be overridden by per-user settings
	&read_file_cached("$mdir/defaultacl", \%rv);

	# If this isn't a master admin user, apply the negative permissions
	# so that he doesn't un-expectedly gain access to new features
	my %gacccess;
	&read_file_cached("$config_directory/$u.acl", \%gaccess);
	if ($gaccess{'negative'}) {
		&read_file_cached("$mdir/negativeacl", \%rv);
		}
	}
my %usersacl;
if (!$_[2] && &supports_rbac($m) && &use_rbac_module_acl($u, $m)) {
	# RBAC overrides exist for this user in this module
	my $rbac = &get_rbac_module_acl(
			defined($_[0]) ? $_[0] : $remote_user, $m);
	foreach my $r (keys %$rbac) {
		$rv{$r} = $rbac->{$r};
		}
	}
elsif ($gconfig{"risk_$u"} && $m) {
	# ACL is defined by user's risk level
	my $rf = $gconfig{"risk_$u"}.'.risk';
	&read_file_cached("$mdir/$rf", \%rv);

	my $sf = $gconfig{"skill_$u"}.'.skill';
	&read_file_cached("$mdir/$sf", \%rv);
	}
elsif ($u ne '') {
	# Use normal Webmin ACL, if a user is set
	my $userdb = &get_userdb_string();
	my $foundindb = 0;
	if ($userdb && ($u ne $base_remote_user || $remote_user_proto)) {
		# Look for this user in the user/group DB, if one is defined
		# and if the user might be in the DB
		my ($dbh, $proto, $prefix, $args) = &connect_userdb($userdb);
		if (!ref($dbh)) {
			print STDERR "Failed to connect to user database : ".
				     $dbh."\n";
			}
		elsif ($proto eq "mysql" || $proto eq "postgresql") {
			# Find the user in the SQL DB
			my $cmd = $dbh->prepare(
				"select id from webmin_user where name = ?");
			$cmd && $cmd->execute($u) ||
				&error(&text('euserdbacl', $dbh->errstr));
			my ($id) = $cmd->fetchrow();
			$foundindb = 1 if (defined($id));
			$cmd->finish();

			# Fetch ACLs with SQL
			if ($foundindb) {
				my $cmd = $dbh->prepare(
				    "select attr,value from webmin_user_acl ".
				    "where id = ? and module = ?");
				$cmd && $cmd->execute($id, $m) ||
				    &error(&text('euserdbacl', $dbh->errstr));
				while(my ($a, $v) = $cmd->fetchrow()) {
					$rv{$a} = $v;
					}
				$cmd->finish();
				}
			}
		elsif ($proto eq "ldap") {
			# Find user in LDAP
			my $rv = $dbh->search(
				base => $prefix,
				filter => '(&(cn='.$u.')(objectClass='.
					  $args->{'userclass'}.'))',
				scope => 'sub');
			if (!$rv || $rv->code) {
				&error(&text('euserdbacl',
				     $rv ? $rv->error : "Unknown error"));
				}
			my ($user) = $rv->all_entries;

			# Find ACL sub-object for the module
			my $ldapm = $m || "global";
			if ($user) {
				my $rv = $dbh->search(
					base => $user->dn(),
					filter => '(cn='.$ldapm.')',
					scope => 'one');
				if (!$rv || $rv->code) {
					&error(&text('euserdbacl',
					   $rv ? $rv->error : "Unknown error"));
					}
				my ($acl) = $rv->all_entries;
				if ($acl) {
					foreach my $av ($acl->get_value(
							'webminAclEntry')) {
						my ($a, $v) = split(/=/, $av,2);
						$rv{$a} = $v;
						}
					}
				}
			}
		if (ref($dbh)) {
			&disconnect_userdb($userdb, $dbh);
			}
		}

	if (!$foundindb) {
		# Read from local files
		&read_file_cached("$config_directory/$m/$u.acl", \%rv);
		if ($remote_user ne $base_remote_user && !defined($_[0])) {
			&read_file_cached(
				"$config_directory/$m/$remote_user.acl",\%rv);
			}
		}
	}
if ($tconfig{'preload_functions'}) {
	&load_theme_library();
	}
if (defined(&theme_get_module_acl)) {
	%rv = &theme_get_module_acl($u, $m, \%rv);
	}
return %rv;
}

=head2 get_group_module_acl(group, [module], [no-default])

Returns the ACL for a Webmin group, in an optional module (which defaults to
the current module).

=cut
sub get_group_module_acl
{
my $g = $_[0];
my $m = defined($_[1]) ? $_[1] : &get_module_name();
my $mdir = &module_root_directory($m);
my %rv;
if (!$_[2]) {
	&read_file_cached("$mdir/defaultacl", \%rv);
	}

my $userdb = &get_userdb_string();
my $foundindb = 0;
if ($userdb) {
	# Look for this group in the user/group DB
	my ($dbh, $proto, $prefix, $args) = &connect_userdb($userdb);
	ref($dbh) || &error(&text('egroupdbacl', $dbh));
	if ($proto eq "mysql" || $proto eq "postgresql") {
		# Find the group in the SQL DB
		my $cmd = $dbh->prepare(
			"select id from webmin_group where name = ?");
		$cmd && $cmd->execute($g) ||
			&error(&text('egroupdbacl', $dbh->errstr));
		my ($id) = $cmd->fetchrow();
		$foundindb = 1 if (defined($id));
		$cmd->finish();

		# Fetch ACLs with SQL
		if ($foundindb) {
			my $cmd = $dbh->prepare(
			    "select attr,value from webmin_group_acl ".
			    "where id = ? and module = ?");
			$cmd && $cmd->execute($id, $m) ||
			    &error(&text('egroupdbacl', $dbh->errstr));
			while(my ($a, $v) = $cmd->fetchrow()) {
				$rv{$a} = $v;
				}
			$cmd->finish();
			}
		}
	elsif ($proto eq "ldap") {
		# Find group in LDAP
		my $rv = $dbh->search(
			base => $prefix,
			filter => '(&(cn='.$g.')(objectClass='.
                                  $args->{'groupclass'}.'))',
			scope => 'sub');
		if (!$rv || $rv->code) {
			&error(&text('egroupdbacl',
				     $rv ? $rv->error : "Unknown error"));
			}
		my ($group) = $rv->all_entries;

		# Find ACL sub-object for the module
		my $ldapm = $m || "global";
		if ($group) {
			my $rv = $dbh->search(
				base => $group->dn(),
				filter => '(cn='.$ldapm.')',
				scope => 'one');
			if (!$rv || $rv->code) {
				&error(&text('egroupdbacl',
				     $rv ? $rv->error : "Unknown error"));
				}
			my ($acl) = $rv->all_entries;
			if ($acl) {
				foreach my $av ($acl->get_value(
						'webminAclEntry')) {
					my ($a, $v) = split(/=/, $av, 2);
					$rv{$a} = $v;
					}
				}
			}
		}
	&disconnect_userdb($userdb, $dbh);
	}
if (!$foundindb) {
	# Read from local files
	&read_file_cached("$config_directory/$m/$g.gacl", \%rv);
	}
if (defined(&theme_get_module_acl)) {
	%rv = &theme_get_module_acl($g, $m, \%rv);
	}
return %rv;
}

=head2 save_module_acl(&acl, [user], [module], [never-update-group])

Updates the acl hash for some user and module. The parameters are :

=item acl - Hash reference for the new access control options, or undef to clear

=item user - User to update, defaulting to the current user.

=item module - Module to update, defaulting to the caller.

=item never-update-group - Never update the user's group's ACL

=cut
sub save_module_acl
{
my $u = defined($_[1]) ? $_[1] : $base_remote_user;
my $m = defined($_[2]) ? $_[2] : &get_module_name();
if (!$_[3] && &foreign_check("acl")) {
	# Check if this user is a member of a group, and if he gets the
	# module from a group. If so, update its ACL as well
	&foreign_require("acl", "acl-lib.pl");
	my $group;
	foreach my $g (&acl::list_groups()) {
		if (&indexof($u, @{$g->{'members'}}) >= 0 &&
		    &indexof($m, @{$g->{'modules'}}) >= 0) {
			$group = $g;
			last;
			}
		}
	if ($group) {
		&save_group_module_acl($_[0], $group->{'name'}, $m);
		}
	}

my $userdb = &get_userdb_string();
my $foundindb = 0;
if ($userdb && ($u ne $base_remote_user || $remote_user_proto)) {
	# Look for this user in the user/group DB
	my ($dbh, $proto, $prefix, $args) = &connect_userdb($userdb);
	ref($dbh) || &error(&text('euserdbacl', $dbh));
	if ($proto eq "mysql" || $proto eq "postgresql") {
		# Find the user in the SQL DB
		my $cmd = $dbh->prepare(
			"select id from webmin_user where name = ?");
		$cmd && $cmd->execute($u) ||
			&error(&text('euserdbacl2', $dbh->errstr));
		my ($id) = $cmd->fetchrow();
		$foundindb = 1 if (defined($id));
		$cmd->finish();

		# Replace ACLs for user
		if ($foundindb) {
			my $cmd = $dbh->prepare("delete from webmin_user_acl ".
						"where id = ? and module = ?");
			$cmd && $cmd->execute($id, $m) ||
			    &error(&text('euserdbacl', $dbh->errstr));
			$cmd->finish();
			if ($_[0]) {
				my $cmd = $dbh->prepare(
				    "insert into webmin_user_acl ".
				    "(id,module,attr,value) values (?,?,?,?)");
				$cmd || &error(&text('euserdbacl2',
						     $dbh->errstr));
				foreach my $a (keys %{$_[0]}) {
					$cmd->execute($id,$m,$a,$_[0]->{$a}) ||
					    &error(&text('euserdbacl2',
							 $dbh->errstr));
					$cmd->finish();
					}
				}
			}
		}
	elsif ($proto eq "ldap") {
		# Find the user in LDAP
		my $rv = $dbh->search(
			base => $prefix,
			filter => '(&(cn='.$u.')(objectClass='.
                                  $args->{'userclass'}.'))',
			scope => 'sub');
		if (!$rv || $rv->code) {
			&error(&text('euserdbacl',
				     $rv ? $rv->error : "Unknown error"));
			}
		my ($user) = $rv->all_entries;

		if ($user) {
			# Find the ACL sub-object for the module
			$foundindb = 1;
			my $ldapm = $m || "global";
			my $rv = $dbh->search(
				base => $user->dn(),
				filter => '(cn='.$ldapm.')',
				scope => 'one');
			if (!$rv || $rv->code) {
				&error(&text('euserdbacl',
				     $rv ? $rv->error : "Unknown error"));
				}
			my ($acl) = $rv->all_entries;

			my @al;
			foreach my $a (keys %{$_[0]}) {
				push(@al, $a."=".$_[0]->{$a});
				}
			if ($acl) {
				# Update attributes
				$rv = $dbh->modify($acl->dn(),
				  replace => { "webminAclEntry", \@al });
				}
			else {
				# Add a sub-object
				my @attrs = ( "cn", $ldapm,
					      "objectClass", "webminAcl",
					      "webminAclEntry", \@al );
				$rv = $dbh->add("cn=".$ldapm.",".$user->dn(),
						attr => \@attrs);
				}
			if (!$rv || $rv->code) {
				&error(&text('euserdbacl2',
				     $rv ? $rv->error : "Unknown error"));
				}
			}
		}
	&disconnect_userdb($userdb, $dbh);
	}

if (!$foundindb) {
	# Save ACL to local file
	if (!-d "$config_directory/$m") {
		mkdir("$config_directory/$m", 0755);
		}
	if ($_[0]) {
		&write_file("$config_directory/$m/$u.acl", $_[0]);
		}
	else {
		&unlink_file("$config_directory/$m/$u.acl");
		}
	}
}

=head2 save_group_module_acl(&acl, group, [module], [never-update-group])

Updates the acl hash for some group and module. The parameters are :

=item acl - Hash reference for the new access control options.

=item group - Group name to update.

=item module - Module to update, defaulting to the caller.

=item never-update-group - Never update the parent group's ACL

=cut
sub save_group_module_acl
{
my $g = $_[1];
my $m = defined($_[2]) ? $_[2] : &get_module_name();
if (!$_[3] && &foreign_check("acl")) {
	# Check if this group is a member of a group, and if it gets the
	# module from a group. If so, update the parent ACL as well
	&foreign_require("acl", "acl-lib.pl");
	my $group;
	foreach my $pg (&acl::list_groups()) {
		if (&indexof('@'.$g, @{$pg->{'members'}}) >= 0 &&
		    &indexof($m, @{$pg->{'modules'}}) >= 0) {
			$group = $g;
			last;
			}
		}
	if ($group) {
		&save_group_module_acl($_[0], $group->{'name'}, $m);
		}
	}

my $userdb = &get_userdb_string();
my $foundindb = 0;
if ($userdb) {
	# Look for this group in the user/group DB
	my ($dbh, $proto, $prefix, $args) = &connect_userdb($userdb);
	ref($dbh) || &error(&text('egroupdbacl', $dbh));
	if ($proto eq "mysql" || $proto eq "postgresql") {
		# Find the group in the SQL DB
		my $cmd = $dbh->prepare(
			"select id from webmin_group where name = ?");
		$cmd && $cmd->execute($g) ||
			&error(&text('egroupdbacl2', $dbh->errstr));
		my ($id) = $cmd->fetchrow();
		$foundindb = 1 if (defined($id));
		$cmd->finish();

		# Replace ACLs for group
		if ($foundindb) {
			my $cmd = $dbh->prepare("delete from webmin_group_acl ".
						"where id = ? and module = ?");
			$cmd && $cmd->execute($id, $m) ||
			    &error(&text('egroupdbacl', $dbh->errstr));
			$cmd->finish();
			if ($_[0]) {
				my $cmd = $dbh->prepare(
				    "insert into webmin_group_acl ".
				    "(id,module,attr,value) values (?,?,?,?)");
				$cmd || &error(&text('egroupdbacl2',
						     $dbh->errstr));
				foreach my $a (keys %{$_[0]}) {
					$cmd->execute($id,$m,$a,$_[0]->{$a}) ||
					    &error(&text('egroupdbacl2',
							 $dbh->errstr));
					$cmd->finish();
					}
				}
			}
		}
	elsif ($proto eq "ldap") {
		# Find the group in LDAP
		my $rv = $dbh->search(
			base => $prefix,
			filter => '(&(cn='.$g.')(objectClass='.
                                  $args->{'groupclass'}.'))',
			scope => 'sub');
		if (!$rv || $rv->code) {
			&error(&text('egroupdbacl',
				     $rv ? $rv->error : "Unknown error"));
			}
		my ($group) = $rv->all_entries;

		my $ldapm = $m || "global";
		if ($group) {
			# Find the ACL sub-object for the module
			$foundindb = 1;
			my $rv = $dbh->search(
				base => $group->dn(),
				filter => '(cn='.$ldapm.')',
				scope => 'one');
			if (!$rv || $rv->code) {
				&error(&text('egroupdbacl',
				     $rv ? $rv->error : "Unknown error"));
				}
			my ($acl) = $rv->all_entries;

			my @al;
			foreach my $a (keys %{$_[0]}) {
				push(@al, $a."=".$_[0]->{$a});
				}
			if ($acl) {
				# Update attributes
				$rv = $dbh->modify($acl->dn(),
			   		replace => { "webminAclEntry", \@al });
				}
			else {
				# Add a sub-object
				my @attrs = ( "cn", $ldapm,
					      "objectClass", "webminAcl",
					      "webminAclEntry", \@al );
				$rv = $dbh->add("cn=".$ldapm.",".$group->dn(),
						attr => \@attrs);
				}
			if (!$rv || $rv->code) {
				&error(&text('egroupdbacl2',
				     $rv ? $rv->error : "Unknown error"));
				}
			}
		}
	&disconnect_userdb($userdb, $dbh);
	}

if (!$foundindb) {
	# Save ACL to local file
	if (!-d "$config_directory/$m") {
		mkdir("$config_directory/$m", 0755);
		}
	if ($_[0]) {
		&write_file("$config_directory/$m/$g.gacl", $_[0]);
		}
	else {
		&unlink_file("$config_directory/$m/$g.gacl");
		}
	}
}

=head2 init_config

This function must be called by all Webmin CGI scripts, either directly or
indirectly via a per-module lib.pl file. It performs a number of initialization
and housekeeping tasks, such as working out the module name, checking that the
current user has access to the module, and populating global variables. Some
of the variables set include :

=item $config_directory - Base Webmin config directory, typically /etc/webmin

=item $var_directory - Base logs directory, typically /var/webmin

=item %config - Per-module configuration.

=item %gconfig - Global configuration.

=item $scriptname - Base name of the current perl script.

=item $module_name - The name of the current module.

=item $module_config_directory - The config directory for this module.

=item $module_config_file - The config file for this module.

=item $module_var_directory - The data directory for this module.

=item $module_root_directory - This module's code directory.

=item $webmin_logfile - The detailed logfile for webmin.

=item $remote_user - The actual username used to login to webmin.

=item $base_remote_user - The username whose permissions are in effect.

=item $current_theme - The theme currently in use.

=item $root_directory - The first root directory of this webmin install.

=item @root_directories - All root directories for this webmin install.

=cut
sub init_config
{
# Record first process ID that called this, so we know when it exited to clean
# up temp files
$main::initial_process_id ||= $$;

# Configuration and spool directories
if (!defined($ENV{'WEBMIN_CONFIG'})) {
	die "WEBMIN_CONFIG not set";
	}
$config_directory = $ENV{'WEBMIN_CONFIG'};
if (!defined($ENV{'WEBMIN_VAR'})) {
	open(VARPATH, "$config_directory/var-path");
	chop($var_directory = <VARPATH>);
	close(VARPATH);
	}
else {
	$var_directory = $ENV{'WEBMIN_VAR'};
	}
$main::http_cache_directory = $ENV{'WEBMIN_VAR'}."/cache";
$main::default_debug_log_file = $ENV{'WEBMIN_VAR'}."/webmin.debug";

if ($ENV{'SESSION_ID'}) {
	# Hide this variable from called programs, but keep it for internal use
	$main::session_id = $ENV{'SESSION_ID'};
	delete($ENV{'SESSION_ID'});
	}
if ($ENV{'REMOTE_PASS'}) {
	# Hide the password too
	$main::remote_pass = $ENV{'REMOTE_PASS'};
	delete($ENV{'REMOTE_PASS'});
	}

if ($> == 0 && $< != 0 && !$ENV{'FOREIGN_MODULE_NAME'}) {
	# Looks like we are running setuid, but the real UID hasn't been set.
	# Do so now, so that executed programs don't get confused
	$( = $);
	$< = $>;
	}

# Read the webmin global config file. This contains the OS type and version,
# OS specific configuration and global options such as proxy servers
$config_file = "$config_directory/config";
%gconfig = ( );
&read_file_cached($config_file, \%gconfig);
$gconfig{'webprefix'} = '' if (!exists($gconfig{'webprefix'}));
$null_file = $gconfig{'os_type'} eq 'windows' ? "NUL" : "/dev/null";
$path_separator = $gconfig{'os_type'} eq 'windows' ? ';' : ':';

# Work out of this is a web, command line or cron job
if (!$main::webmin_script_type) {
	if ($ENV{'SCRIPT_NAME'}) {
		# Run via a CGI
		$main::webmin_script_type = 'web';
		}
	else {
		# Cron jobs have no TTY
		if ($gconfig{'os_type'} eq 'windows' ||
		    open(DEVTTY, ">/dev/tty")) {
			$main::webmin_script_type = 'cmd';
			close(DEVTTY);
			}
		else {
			$main::webmin_script_type = 'cron';
			}
		}
	}

# If this is a cron job, suppress STDERR warnings
if ($main::webmin_script_type eq 'cron') {
	$SIG{__WARN__} = sub { };
	}

# If debugging is enabled, open the debug log
if (($ENV{'WEBMIN_DEBUG'} || $gconfig{'debug_enabled'}) &&
    !$main::opened_debug_log++) {
	my $dlog = $gconfig{'debug_file'} || $main::default_debug_log_file;
	my $dsize = $gconfig{'debug_size'} || $main::default_debug_log_size;
	my @st = stat($dlog);
	if ($dsize && $st[7] > $dsize) {
		rename($dlog, $dlog.".0");
		}

	open(main::DEBUGLOG, ">>$dlog");
	$main::opened_debug_log = 1;

	if ($gconfig{'debug_what_start'}) {
		my $script_name = $0 =~ /([^\/]+)$/ ? $1 : '-';
		$main::debug_log_start_time = time();
		&webmin_debug_log("START", "script=$script_name");
		}
	}

# Set PATH and LD_LIBRARY_PATH
if ($gconfig{'path'}) {
	if ($gconfig{'syspath'}) {
		# Webmin only
		$ENV{'PATH'} = $gconfig{'path'};
		}
	else {
		# Include OS too
		$ENV{'PATH'} = $gconfig{'path'}.$path_separator.$ENV{'PATH'};
		}
	}
$ENV{$gconfig{'ld_env'}} = $gconfig{'ld_path'} if ($gconfig{'ld_env'});

# Set http_proxy and ftp_proxy environment variables, based on Webmin settings
if ($gconfig{'http_proxy'}) {
	$ENV{'http_proxy'} = $gconfig{'http_proxy'};
	}
if ($gconfig{'ftp_proxy'}) {
	$ENV{'ftp_proxy'} = $gconfig{'ftp_proxy'};
	}
if ($gconfig{'noproxy'}) {
	$ENV{'no_proxy'} = $gconfig{'noproxy'};
	}

# Find all root directories
my %miniserv;
if (&get_miniserv_config(\%miniserv)) {
	@root_directories = ( $miniserv{'root'} );
	for($i=0; defined($miniserv{"extraroot_$i"}); $i++) {
		push(@root_directories, $miniserv{"extraroot_$i"});
		}
	}

# Work out which module we are in, and read the per-module config file
$0 =~ s/\\/\//g;	# Force consistent path on Windows
if (defined($ENV{'FOREIGN_MODULE_NAME'}) && $ENV{'FOREIGN_ROOT_DIRECTORY'}) {
	# In a foreign call - use the module name given
	$root_directory = $ENV{'FOREIGN_ROOT_DIRECTORY'};
	$module_name = $ENV{'FOREIGN_MODULE_NAME'};
	@root_directories = ( $root_directory ) if (!@root_directories);
	}
elsif ($ENV{'SCRIPT_NAME'}) {
	my $sn = $ENV{'SCRIPT_NAME'};
	$sn =~ s/^$gconfig{'webprefix'}//
		if (!$gconfig{'webprefixnoredir'});
	if ($sn =~ /^\/([^\/]+)\//) {
		# Get module name from CGI path
		$module_name = $1;
		}
	if ($ENV{'SERVER_ROOT'}) {
		$root_directory = $ENV{'SERVER_ROOT'};
		}
	elsif ($ENV{'SCRIPT_FILENAME'}) {
		$root_directory = $ENV{'SCRIPT_FILENAME'};
		$root_directory =~ s/$sn$//;
		}
	@root_directories = ( $root_directory ) if (!@root_directories);
	}
else {
	# Get root directory from miniserv.conf, and deduce module name from $0
	$root_directory = $root_directories[0];
	my $rok = 0;
	foreach my $r (@root_directories) {
		if ($0 =~ /^$r\/([^\/]+)\/[^\/]+$/i) {
			# Under a module directory
			$module_name = $1;
			$rok = 1;
			last;
			}
		elsif ($0 =~ /^$root_directory\/[^\/]+$/i) {
			# At the top level
			$rok = 1;
			last;
			}
		}
	&error("Script was not run with full path (failed to find $0 under $root_directory)") if (!$rok);
	}

# Set the umask based on config
if ($gconfig{'umask'} ne '' && !$main::umask_already++) {
	umask(oct($gconfig{'umask'}));
	}

# If this is a cron job or other background task, set the nice level
if (!$main::nice_already && $main::webmin_script_type eq 'cron') {
	# Set nice level
	if ($gconfig{'nice'}) {
		eval 'POSIX::nice($gconfig{\'nice\'});';
		}

	# Set IO scheduling class and priority
	if ($gconfig{'sclass'} ne '' || $gconfig{'sprio'} ne '') {
		my $cmd = "ionice";
		$cmd .= " -c ".quotemeta($gconfig{'sclass'})
			if ($gconfig{'sclass'} ne '');
		$cmd .= " -n ".quotemeta($gconfig{'sprio'})
			if ($gconfig{'sprio'} ne '');
		$cmd .= " -p $$";
		&execute_command("$cmd >/dev/null 2>&1");
		}
	}
$main::nice_already++;

# Get the username
my $u = $ENV{'BASE_REMOTE_USER'} || $ENV{'REMOTE_USER'};
$base_remote_user = $u;
$remote_user = $ENV{'REMOTE_USER'};

# Work out if user is definitely in the DB, and if so get his attrs
$remote_user_proto = $ENV{"REMOTE_USER_PROTO"};
%remote_user_attrs = ( );
if ($remote_user_proto) {
	my $userdb = &get_userdb_string();
	my ($dbh, $proto, $prefix, $args) =
		$userdb ? &connect_userdb($userdb) : ( );
	if (ref($dbh)) {
		if ($proto eq "mysql" || $proto eq "postgresql") {
			# Read attrs from SQL
			my $cmd = $dbh->prepare("select webmin_user_attr.attr,webmin_user_attr.value from webmin_user_attr,webmin_user where webmin_user_attr.id = webmin_user.id and webmin_user.name = ?");
			if ($cmd && $cmd->execute($base_remote_user)) {
				while(my ($attr, $value) = $cmd->fetchrow()) {
					$remote_user_attrs{$attr} = $value;
					}
				$cmd->finish();
				}
			}
		elsif ($proto eq "ldap") {
			# Read attrs from LDAP
			my $rv = $dbh->search(
				base => $prefix,
				filter => '(&(cn='.$base_remote_user.')'.
					  '(objectClass='.
					  $args->{'userclass'}.'))',
				scope => 'sub');
			my ($u) = $rv && !$rv->code ? $rv->all_entries : ( );
			if ($u) {
				foreach $la ($u->get_value('webminAttr')) {
					my ($attr, $value) = split(/=/, $la, 2);
					$remote_user_attrs{$attr} = $value;
					}
				}
			}
		&disconnect_userdb($userdb, $dbh);
		}
	}

if ($module_name) {
	# Find and load the configuration file for this module
	my (@ruinfo, $rgroup);
	$module_config_directory = "$config_directory/$module_name";
	if (&get_product_name() eq "usermin" &&
	    -r "$module_config_directory/config.$remote_user") {
		# Based on username
		$module_config_file = "$module_config_directory/config.$remote_user";
		}
	elsif (&get_product_name() eq "usermin" &&
	    (@ruinfo = getpwnam($remote_user)) &&
	    ($rgroup = getgrgid($ruinfo[3])) &&
	    -r "$module_config_directory/config.\@$rgroup") {
		# Based on group name
		$module_config_file = "$module_config_directory/config.\@$rgroup";
		}
	else {
		# Global config
		$module_config_file = "$module_config_directory/config";
		}
	%config = ( );
	&read_file_cached($module_config_file, \%config);

	# Create a module-specific var directory
	my $var_base = "$var_directory/modules";
	if (!-d $var_base) {
		&make_dir($var_base, 0700);
		}
	$module_var_directory = "$var_base/$module_name";
	if (!-d $module_var_directory) {
		&make_dir($module_var_directory, 0700);
		}

	# Fix up windows-specific substitutions in values
	foreach my $k (keys %config) {
		if ($config{$k} =~ /\$\{systemroot\}/) {
			my $root = &get_windows_root();
			$config{$k} =~ s/\$\{systemroot\}/$root/g;
			}
		}
	}

# Record the initial module
$main::initial_module_name ||= $module_name;

# Set some useful variables
my $current_themes;
$current_themes = $ENV{'MOBILE_DEVICE'} && defined($gconfig{'mobile_theme'}) ?
		    $gconfig{'mobile_theme'} :
		  defined($remote_user_attrs{'theme'}) ?
		    $remote_user_attrs{'theme'} :
		  defined($gconfig{'theme_'.$remote_user}) ?
		    $gconfig{'theme_'.$remote_user} :
		  defined($gconfig{'theme_'.$base_remote_user}) ?
		    $gconfig{'theme_'.$base_remote_user} :
		    $gconfig{'theme'};
@current_themes = split(/\s+/, $current_themes);
$current_theme = $current_themes[0];
@theme_root_directories = map { "$root_directory/$_" } @current_themes;
$theme_root_directory = $theme_root_directories[0];
@theme_configs = ( );
foreach my $troot (@theme_root_directories) {
	my %onetconfig;
	&read_file_cached("$troot/config", \%onetconfig);
	&read_file_cached("$troot/config", \%tconfig);
	push(@theme_configs, \%onetconfig);
	}
$tb = defined($tconfig{'cs_header'}) ? "bgcolor=\"#$tconfig{'cs_header'}\"" :
      defined($gconfig{'cs_header'}) ? "bgcolor=\"#$gconfig{'cs_header'}\"" :
				       "bgcolor=\"#9999ff\"";
$cb = defined($tconfig{'cs_table'}) ? "bgcolor=\"#$tconfig{'cs_table'}\"" :
      defined($gconfig{'cs_table'}) ? "bgcolor=\"#$gconfig{'cs_table'}\"" :
				      "bgcolor=\"#cccccc\"";
$tb .= ' '.$tconfig{'tb'} if ($tconfig{'tb'});
$cb .= ' '.$tconfig{'cb'} if ($tconfig{'cb'});
if ($tconfig{'preload_functions'}) {
	# Force load of theme functions right now, if requested
	&load_theme_library();
	}
if ($tconfig{'oofunctions'} && !$main::loaded_theme_oo_library++) {
	# Load the theme's Webmin:: package classes
	do "$theme_root_directory/$tconfig{'oofunctions'}";
	}

$0 =~ /([^\/]+)$/;
$scriptname = $1;
$webmin_logfile = $gconfig{'webmin_log'} ? $gconfig{'webmin_log'}
					 : "$var_directory/webmin.log";

# Load language strings into %text
my @langs = &list_languages();
my $accepted_lang;
if ($gconfig{'acceptlang'}) {
	foreach my $a (split(/,/, $ENV{'HTTP_ACCEPT_LANGUAGE'})) {
		$a =~ s/;.*//;	# Remove ;q=0.5 or similar
		my ($al) = grep { $_->{'lang'} eq $a } @langs;
		if ($al) {
			$accepted_lang = $al->{'lang'};
			last;
			}
		}
	}
$current_lang = $force_lang ? $force_lang :
    $accepted_lang ? $accepted_lang :
    $remote_user_attrs{'lang'} ? $remote_user_attrs{'lang'} :
    $gconfig{"lang_$remote_user"} ? $gconfig{"lang_$remote_user"} :
    $gconfig{"lang_$base_remote_user"} ? $gconfig{"lang_$base_remote_user"} :
    $gconfig{"lang"} ? $gconfig{"lang"} : $default_lang;
foreach my $l (@langs) {
	$current_lang_info = $l if ($l->{'lang'} eq $current_lang);
	}
@lang_order_list = &unique($default_lang,
		     	   split(/:/, $current_lang_info->{'fallback'}),
			   $current_lang);
%text = &load_language($module_name);
%text || &error("Failed to determine Webmin root from SERVER_ROOT, SCRIPT_FILENAME or the full command line");

# Get the %module_info for this module
if ($module_name) {
	my ($mi) = grep { $_->{'dir'} eq $module_name }
			 &get_all_module_infos(2);
	%module_info = %$mi;
	$module_root_directory = &module_root_directory($module_name);
	}

if ($module_name && !$main::no_acl_check &&
    !defined($ENV{'FOREIGN_MODULE_NAME'}) &&
    $main::webmin_script_type eq 'web') {
	# Check if the HTTP user can access this module
	if (!&foreign_available($module_name)) {
		if (!&foreign_check($module_name)) {
			&error(&text('emodulecheck',
				     "<i>$module_info{'desc'}</i>"));
			}
		else {
			&error(&text('emodule', "<i>$u</i>",
				     "<i>$module_info{'desc'}</i>"));
			}
		}
	$main::no_acl_check++;
	}

# Check the Referer: header for nasty redirects
my @referers = split(/\s+/, $gconfig{'referers'});
my $referer_site;
my $r = $ENV{'HTTP_REFERER'};
my $referer_port = $r =~ /^https:/ ? 443 : 80;
if ($r =~ /^(http|https|ftp):\/\/([^:\/]+:[^@\/]+@)?\[([^\]]+)\](:(\d+))?/ ||
    $r =~ /^(http|https|ftp):\/\/([^:\/]+:[^@\/]+@)?([^\/:@]+)(:(\d+))?/) {
	$referer_site = $3;
	$referer_port = $5 if ($5);
	}
my $http_host = $ENV{'HTTP_HOST'};
my $http_port = $ENV{'SERVER_PORT'} || 80;
if ($http_host =~ s/:(\d+)$//) {
	$http_port = $1;
	}
$http_host =~ s/^\[(\S+)\]$/$1/;
my $unsafe_index = $unsafe_index_cgi ||
		   &get_module_variable('$unsafe_index_cgi');
my $trustvar = $trust_unknown_referers ||
	       &get_module_variable('$trust_unknown_referers');
my $trust = 0;
if (!$0) {
	# Script name not known
	$trust = 1;
	}
elsif ($trustvar == 1) {
	# Module doesn't want referer checking at all
	$trust = 1;
	}
elsif ($ENV{'DISABLE_REFERERS_CHECK'}) {
	# Check disabled by environment, perhaps due to cross-module call
	$trust = 1;
	}
elsif (($ENV{'SCRIPT_NAME'} =~ /^\/(index.cgi)?$/ ||
	$ENV{'SCRIPT_NAME'} =~ /^\/([a-z0-9\_\-]+)\/(index.cgi)?$/i) &&
       !$unsafe_index) {
	# Script is a module's index.cgi, which is normally safe
	$trust = 1;
	}
elsif ($0 =~ /(session_login|pam_login)\.cgi$/) {
	# Webmin login page, which doesn't get a referer
	$trust = 1;
	}
elsif ($gconfig{'referer'}) {
	# Referer checking disabled completely
	$trust = 1;
	}
elsif (!$ENV{'MINISERV_CONFIG'}) {
	# Not a CGI script
	$trust = 1;
	}
elsif ($main::no_referers_check) {
	# Caller requested disabling of checks completely
	$trust = 1;
	}
elsif ($ENV{'HTTP_USER_AGENT'} =~ /^Webmin/i) {
	# Remote call from Webmin itself
	$trust = 1;
	}
elsif (!$referer_site) {
	# No referer set in URL
	if (!$gconfig{'referers_none'}) {
		# Known referers are allowed
		$trust = 1;
		}
	elsif ($trustvar == 2) {
		# Module wants to trust unknown referers
		$trust = 1;
		}
	else {
		$trust = 0;
		}
	}
elsif (&indexof($referer_site, @referers) >= 0) {
	# Site is on the trusted list
	$trust = 1;
	}
elsif ($referer_site eq $http_host &&
       (!$referer_port || !$http_port || $referer_port == $http_port)) {
	# Link came from this website
	$trust = 1;
	}
else {
	# Unknown link source
	$trust = 0;
	}
# Check for trigger URL to simply redirect to root: required for Authentic Theme 19.00+
if ($ENV{'HTTP_X_REQUESTED_WITH'} ne "XMLHttpRequest" &&
    $ENV{'REQUEST_URI'} !~ /xhr/  &&
    $ENV{'REQUEST_URI'} !~ /pjax/ &&
		$ENV{'REQUEST_URI'} !~ /link.cgi\/\d+/ &&
    $ENV{'REQUEST_URI'} =~ /xnavigation=1/) {
		# Store requested URI if safe
		if ($main::session_id && $remote_user) {
	    my %var;
	    my $key  = 'goto';
	    my $xnav = "xnavigation=1";
	    my $url  = "$gconfig{'webprefix'}$ENV{'REQUEST_URI'}";
	    my $salt = substr(encode_base64($main::session_id), 0, 16);
	    $url =~ s/[?|&]$xnav//g;
	    $salt =~ tr/A-Za-z0-9//cd;

	    if (!$trust) {
	        my @parent_dir = split('/', $url);
	        $url = $gconfig{'webprefix'} ? $parent_dir[2] : $parent_dir[1];
	        if ($url =~ /.cgi/) {
	            $url = "/";
	        	}
					else {
	            $url = "/" . $url . "/";
	        	}
	    	}
			# Append hex URL representation to stored file name, to process multiple, simultaneous requests
			my $url_salt  = substr(unpack("H*", $url), -180);
	    $var{$key} = $url;
	    write_file(tempname('.theme_' . $salt . '_' . $url_salt . '_' . get_product_name() . '_' . $key . '_' . $remote_user), \%var);
		}
  &redirect("/");
	}
if (!$trust) {
	# Looks like a link from elsewhere .. show an error
	&header($text{'referer_title'}, "", undef, 0, 1, 1);

	$prot = lc($ENV{'HTTPS'}) eq 'on' ? "https" : "http";
	my $url = "<tt>".&html_escape("$prot://$ENV{'HTTP_HOST'}$ENV{'REQUEST_URI'}")."</tt>";
	if ($referer_site) {
		# From a known host
		print &text('referer_warn',
			    "<tt>".&html_escape($r)."</tt>", $url);
		print "<p>\n";
		print &text('referer_fix1', &html_escape($http_host)),"<p>\n";
		print &text('referer_fix2', &html_escape($http_host)),"<p>\n";
		}
	else {
		# No referer info given
		print &text('referer_warn_unknown', $url),"<p>\n";
		print &text('referer_fix3u'),"<p>\n";
		print &text('referer_fix2u'),"<p>\n";
		}
	print "<p>\n";

	exit;
	}
$main::no_referers_check++;
$main::completed_referers_check++;

# Call theme post-init
if (defined(&theme_post_init_config)) {
	&theme_post_init_config(@_);
	}

# Record that we have done the calling library in this package
my ($callpkg, $lib) = caller();
$lib =~ s/^.*\///;
$main::done_foreign_require{$callpkg,$lib} = 1;

# If a licence checking is enabled, do it now
if ($gconfig{'licence_module'} && !$main::done_licence_module_check &&
    &foreign_check($gconfig{'licence_module'}) &&
    -r "$root_directory/$gconfig{'licence_module'}/licence_check.pl") {
	my $oldpwd = &get_current_dir();
	$main::done_licence_module_check++;
	$main::licence_module = $gconfig{'licence_module'};
	&foreign_require($main::licence_module, "licence_check.pl");
	($main::licence_status, $main::licence_message) =
		&foreign_call($main::licence_module, "check_licence");
	chdir($oldpwd);
	}

# Export global variables to caller
if ($main::export_to_caller) {
	foreach my $v ('$config_file', '%gconfig', '$null_file',
		       '$path_separator', '@root_directories',
		       '$root_directory', '$module_name',
		       '$base_remote_user', '$remote_user',
		       '$remote_user_proto', '%remote_user_attrs',
		       '$module_config_directory', '$module_config_file',
		       '%config', '@current_themes', '$current_theme',
		       '@theme_root_directories', '$theme_root_directory',
		       '%tconfig','@theme_configs', '$tb', '$cb', '$scriptname',
		       '$webmin_logfile', '$current_lang',
		       '$current_lang_info', '@lang_order_list', '%text',
		       '%module_info', '$module_root_directory',
		       '$module_var_directory') {
		my ($vt, $vn) = split('', $v, 2);
		eval "${vt}${callpkg}::${vn} = ${vt}${vn}";
		}
	}

return 1;
}

=head2 load_language([module], [directory])

Returns a hashtable mapping text codes to strings in the appropriate language,
based on the $current_lang global variable, which is in turn set based on
the Webmin user's selection. The optional module parameter tells the function
which module to load strings for, and defaults to the calling module. The
optional directory parameter can be used to load strings from a directory
other than lang.

In regular module development you will never need to call this function
directly, as init_config calls it for you, and places the module's strings
into the %text hash.

=cut
sub load_language
{
my %text;
my $root = $root_directory;
my $ol = $gconfig{'overlang'};
my ($dir) = ($_[1] || "lang");

# Read global lang files
foreach my $o (@lang_order_list) {
	my $ok = &read_file_cached_with_stat("$root/$dir/$o", \%text);
	return () if (!$ok && $o eq $default_lang);
	}
if ($ol) {
	foreach my $o (@lang_order_list) {
		&read_file_cached("$root/$ol/$o", \%text);
		}
	}
&read_file_cached("$config_directory/custom-lang", \%text);
foreach my $o (@lang_order_list) {
	next if ($o eq "en");
	&read_file_cached("$config_directory/custom-lang.$o", \%text);
	}
my $norefs = $text{'__norefs'};

if ($_[0]) {
	# Read module's lang files
	delete($text{'__norefs'});
	my $mdir = &module_root_directory($_[0]);
	foreach my $o (@lang_order_list) {
		&read_file_cached_with_stat("$mdir/$dir/$o", \%text);
		}
	if ($ol) {
		foreach my $o (@lang_order_list) {
			&read_file_cached("$mdir/$ol/$o", \%text);
			}
		}
	&read_file_cached("$config_directory/$_[0]/custom-lang", \%text);
	foreach my $o (@lang_order_list) {
		next if ($o eq "en");
		&read_file_cached("$config_directory/$_[0]/custom-lang.$o",
				  \%text);
		}
	$norefs = $text{'__norefs'} if ($norefs);
	}

# Replace references to other strings
if (!$norefs) {
	foreach $k (keys %text) {
		$text{$k} =~ s/\$(\{([^\}]+)\}|([A-Za-z0-9\.\-\_]+))/text_subs($2 || $3,\%text)/ge;
		}
	}

if (defined(&theme_load_language)) {
	&theme_load_language(\%text, $_[0]);
	}
return %text;
}

=head2 text_subs(string)

Used internally by load_language to expand $code substitutions in language
files.

=cut
sub text_subs
{
if (substr($_[0], 0, 8) eq "include:") {
	local $_;
	my $rv;
	open(INCLUDE, substr($_[0], 8));
	while(<INCLUDE>) {
		$rv .= $_;
		}
	close(INCLUDE);
	return $rv;
	}
else {
	my $t = $_[1]->{$_[0]};
	return defined($t) ? $t : '$'.$_[0];
	}
}

=head2 text(message, [substitute]+)

Returns a translated message from %text, but with $1, $2, etc.. replaced with
the substitute parameters. This makes it easy to use strings with placeholders
that get replaced with programmatically generated text. For example :

 print &text('index_hello', $remote_user),"<p>\n";

=cut
sub text
{
my $t = &get_module_variable('%text', 1);
my $rv = exists($t->{$_[0]}) ? $t->{$_[0]} : $text{$_[0]};
$rv =~ s/\$(\d+)/$1 < @_ ? $_[$1] : '$'.$1/ge;
return $rv;
}

=head2 encode_base64(string)

Encodes a string into base64 format, for use in MIME email or HTTP
authorization headers.

=cut
sub encode_base64
{
eval "use MIME::Base64 ()";
if (!$@) {
	return MIME::Base64::encode($_[0]);
	}
my $res;
pos($_[0]) = 0;                          # ensure start at the beginning
while ($_[0] =~ /(.{1,57})/gs) {
	$res .= substr(pack('u57', $1), 1)."\n";
	chop($res);
	}
$res =~ tr|\` -_|AA-Za-z0-9+/|;
my $padding = (3 - length($_[0]) % 3) % 3;
$res =~ s/.{$padding}$/'=' x $padding/e if ($padding);
return $res;
}

=head2 decode_base64(string)

Converts a base64-encoded string into plain text. The opposite of encode_base64.

=cut
sub decode_base64
{
eval "use MIME::Base64 ()";
if (!$@) {
	return MIME::Base64::decode($_[0]);
	}
my ($str) = @_;
my $res;
$str =~ tr|A-Za-z0-9+=/||cd;            # remove non-base64 chars
if (length($str) % 4) {
	return undef;
}
$str =~ s/=+$//;                        # remove padding
$str =~ tr|A-Za-z0-9+/| -_|;            # convert to uuencoded format
while ($str =~ /(.{1,60})/gs) {
        my $len = chr(32 + length($1)*3/4); # compute length byte
        $res .= unpack("u", $len . $1 );    # uudecode
	}
return $res;
}

=head2 encode_base32(string)

Encodes a string into base32 format.

=cut
sub encode_base32
{
$_ = shift @_;
my ($buffer, $l, $e);
$_ = unpack('B*', $_);
s/(.....)/000$1/g;
$l = length;
if ($l & 7) {
	$e = substr($_, $l & ~7);
	$_ = substr($_, 0, $l & ~7);
	$_ .= "000$e" . '0' x (5 - length $e);
	}
$_ = pack('B*', $_);
tr|\0-\37|A-Z2-7|;
$_;
}

=head2 decode_base32(string)

Converts a base32-encoded string into plain text. The opposite of encode_base32.

=cut
sub decode_base32
{
$_ = shift;
my ($l);
tr|A-Z2-7|\0-\37|;
$_ = unpack('B*', $_);
s/000(.....)/$1/g;
$l = length;
$_ = substr($_, 0, $l & ~7) if $l & 7;
$_ = pack('B*', $_);
return $_;
}

=head2 get_module_info(module, [noclone], [forcache])

Returns a hash containg details of the given module. Some useful keys are :

=item dir - The module directory, like sendmail.

=item desc - Human-readable description, in the current users' language.

=item version - Optional module version number.

=item os_support - List of supported operating systems and versions.

=item category - Category on Webmin's left menu, like net.

=cut
sub get_module_info
{
return () if ($_[0] =~ /^\./);
my (%rv, $clone, $o);
my $mdir = &module_root_directory($_[0]);
&read_file_cached("$mdir/module.info", \%rv) || return ();
if (-l $mdir) {
	# A clone is a module that links to another directory under the root
	foreach my $r (@root_directories) {
		if (&is_under_directory($r, $mdir)) {
			$clone = readlink($mdir);
			$clone =~ s/^.*\///;
			last;
			}
		}
	}

# Apply language-specific override files
foreach $o (@lang_order_list) {
	next if ($o eq "en");
	&read_file_cached("$mdir/module.info.$o", \%rv);
	}

# Apply desc_$LANG overrides
foreach $o (@lang_order_list) {
	$rv{"desc"} = $rv{"desc_$o"} if ($rv{"desc_$o"});
	$rv{"longdesc"} = $rv{"longdesc_$o"} if ($rv{"longdesc_$o"});
	}

# Apply overrides if this is a cloned module
if ($clone && !$_[1] && $config_directory) {
	$rv{'clone'} = $rv{'desc'};
	$rv{'cloneof'} = $clone;
	&read_file("$config_directory/$_[0]/clone", \%rv);
	}
$rv{'dir'} = $_[0];
my %module_categories;
&read_file_cached("$config_directory/webmin.cats", \%module_categories);
my $pn = &get_product_name();
if (defined($rv{'category_'.$pn})) {
	# Can override category for webmin/usermin
	$rv{'category'} = $rv{'category_'.$pn};
	}
$rv{'realcategory'} = $rv{'category'};
$rv{'category'} = $module_categories{$_[0]}
	if (defined($module_categories{$_[0]}));

# Apply site-specific description overrides
$rv{'realdesc'} = $rv{'desc'};
my %descs;
&read_file_cached("$config_directory/webmin.descs", \%descs);
if ($descs{$_[0]}) {
	$rv{'desc'} = $descs{$_[0]};
	}
foreach my $o (@lang_order_list) {
	my $ov = $descs{$_[0]." ".$o} || $descs{$_[0]."_".$o};
	$rv{'desc'} = $ov if ($ov);
	}

if (!$_[2]) {
	# Apply per-user description override
	my %gaccess = &get_module_acl(undef, "");
	if ($gaccess{'desc_'.$_[0]}) {
		$rv{'desc'} = $gaccess{'desc_'.$_[0]};
		}
	}

if ($rv{'longdesc'}) {
	# All standard modules have an index.cgi
	$rv{'index_link'} = 'index.cgi';
	}

# Call theme-specific override function
if (defined(&theme_get_module_info)) {
	%rv = &theme_get_module_info(\%rv, $_[0], $_[1], $_[2]);
	}

return %rv;
}

=head2 get_all_module_infos(cachemode)

Returns a list contains the information on all modules in this webmin
install, including clones. Uses caching to reduce the number of module.info
files that need to be read. Each element of the array is a hash reference
in the same format as returned by get_module_info. The cache mode flag can be :
0 = read and write, 1 = don't read or write, 2 = read only

=cut
sub get_all_module_infos
{
my (%cache, @rv);

# Is the cache out of date? (ie. have any of the root's changed?)
my $cache_file = "$config_directory/module.infos.cache";
if (!-r $cache_file) {
	$cache_file = "$var_directory/module.infos.cache";
	}
my $changed = 0;
if (&read_file_cached($cache_file, \%cache)) {
	foreach my $r (@root_directories) {
		my @st = stat($r);
		if ($st[9] != $cache{'mtime_'.$r}) {
			$changed = 2;
			last;
			}
		}
	}
else {
	$changed = 1;
	}

if ($_[0] != 1 && !$changed && $cache{'lang'} eq $current_lang) {
	# Can use existing module.info cache
	my %mods;
	foreach my $k (keys %cache) {
		if ($k =~ /^(\S+) (\S+)$/) {
			$mods{$1}->{$2} = $cache{$k};
			}
		}
	@rv = map { $mods{$_} } (keys %mods) if (%mods);
	}
else {
	# Need to rebuild cache
	%cache = ( );
	foreach my $r (@root_directories) {
		opendir(DIR, $r);
		foreach my $m (readdir(DIR)) {
			next if ($m =~ /^(config-|\.)/ || $m =~ /\.(cgi|pl)$/);
			my %minfo = &get_module_info($m, 0, 1);
			next if (!%minfo || !$minfo{'dir'});
			push(@rv, \%minfo);
			foreach $k (keys %minfo) {
				$cache{"${m} ${k}"} = $minfo{$k};
				}
			}
		closedir(DIR);
		my @st = stat($r);
		$cache{'mtime_'.$r} = $st[9];
		}
	$cache{'lang'} = $current_lang;
	if (!$_[0] && $< == 0 && $> == 0) {
		eval {
			# Don't fail if cache write fails
			local $main::error_must_die = 1;
			&write_file($cache_file, \%cache);
			}
		}
	}

# Override descriptions for modules for current user
my %gaccess = &get_module_acl(undef, "");
foreach my $m (@rv) {
	if ($gaccess{"desc_".$m->{'dir'}}) {
		$m->{'desc'} = $gaccess{"desc_".$m->{'dir'}};
		}
	}

# Apply installed flags
my %installed;
&read_file_cached("$config_directory/installed.cache", \%installed);
foreach my $m (@rv) {
	$m->{'installed'} = $installed{$m->{'dir'}};
	}

return @rv;
}

=head2 list_themes

Returns an array of all installed themes, each of which is a hash ref
corresponding to the theme.info file.

=cut
sub list_themes
{
my @rv;
opendir(DIR, $root_directory);
foreach my $m (readdir(DIR)) {
	my %tinfo;
	next if ($m =~ /^\./);
	next if (!&read_file_cached("$root_directory/$m/theme.info", \%tinfo));
	next if (!&check_os_support(\%tinfo));
	foreach my $o (@lang_order_list) {
		if ($tinfo{'desc_'.$o}) {
			$tinfo{'desc'} = $tinfo{'desc_'.$o};
			}
		}
	$tinfo{'dir'} = $m;
	push(@rv, \%tinfo);
	}
closedir(DIR);
return sort { lc($a->{'desc'}) cmp lc($b->{'desc'}) } @rv;
}

=head2 get_theme_info(theme)

Returns a hash containing a theme's details, taken from it's theme.info file.
Some useful keys are :

=item dir - The theme directory, like blue-theme.

=item desc - Human-readable description, in the current users' language.

=item version - Optional module version number.

=item os_support - List of supported operating systems and versions.

=cut
sub get_theme_info
{
return () if ($_[0] =~ /^\./);
my %rv;
my $tdir = &module_root_directory($_[0]);
&read_file("$tdir/theme.info", \%rv) || return ();
foreach my $o (@lang_order_list) {
	$rv{"desc"} = $rv{"desc_$o"} if ($rv{"desc_$o"});
	}
$rv{"dir"} = $_[0];
return %rv;
}

=head2 list_languages(current-lang)

Returns an array of supported languages, taken from Webmin's os_list.txt file.
Each is a hash reference with the following keys :

=item lang - The short language code, like es for Spanish.

=item desc - A human-readable description, in English.

=item charset - An optional character set to use when displaying the language.

=item titles - Set to 1 only if Webmin has title images for the language.

=item fallback - The code for another language to use if a string does not exist in this one. For all languages, English is the ultimate fallback.

=cut
sub list_languages
{
my ($current) = @_;
if (!@main::list_languages_cache) {
	my $o;
	local $_;
	open(LANG, "$root_directory/lang_list.txt");
	while(<LANG>) {
		if (/^(\S+)\s+(.*)/) {
			my $l = { 'desc' => $2 };
			foreach $o (split(/,/, $1)) {
				if ($o =~ /^([^=]+)=(.*)$/) {
					$l->{$1} = $2;
					}
				}
			$l->{'index'} = scalar(@main::list_languages_cache);
			push(@main::list_languages_cache, $l);
			my $utf8lang = $l->{'lang'};
			$utf8lang =~ s/\.(\S+)$//;
			$utf8lang =~ s/_RU$//;
			$utf8lang .= ".UTF-8";
			if ($l->{'charset'} ne 'UTF-8' &&
			    ($l->{'charset'} eq 'iso-8859-1' ||
		             $l->{'charset'} eq 'iso-8859-2' ||
			     -r "$root_directory/lang/$utf8lang")) {
				# Add UTF-8 variant
				my $ul = { %$l };
				$ul->{'charset'} = 'UTF-8';
				$ul->{'lang'} = $utf8lang;
				$ul->{'index'} =
					scalar(@main::list_languages_cache);
				$l->{'utf8_variant'} = $ul;
				push(@main::list_languages_cache, $ul);
				}
			}
		}
	close(LANG);
	@main::list_languages_cache = sort { $a->{'desc'} cmp $b->{'desc'} }
				     @main::list_languages_cache;
	}
if ($current && $current =~ /\.UTF-8$/) {
	# If the user is already using a UTF-8 language encoding, filter out
	# languages that have a UTF-8 variant
	return grep { $_->{'charset'} eq 'UTF-8' ||
		      !$_->{'utf8_variant'} } @main::list_languages_cache;
	}
return @main::list_languages_cache;
}

=head2 read_env_file(file, &hash, [include-commented])

Similar to Webmin's read_file function, but handles files containing shell
environment variables formatted like :

  export FOO=bar
  SMEG="spod"

The file parameter is the full path to the file to read, and hash a Perl hash
ref to read names and values into.

=cut
sub read_env_file
{
local $_;
&open_readfile(FILE, $_[0]) || return 0;
while(<FILE>) {
	if ($_[2]) {
		# Remove start of line comments
		s/^\s*#+\s*//;
		}
	s/#.*$//g;
	if (/^\s*(export\s*)?([A-Za-z0-9_\.]+)\s*=\s*"(.*)"/i ||
	    /^\s*(export\s*)?([A-Za-z0-9_\.]+)\s*=\s*'(.*)'/i ||
	    /^\s*(export\s*)?([A-Za-z0-9_\.]+)\s*=\s*(.*)/i) {
		$_[1]->{$2} = $3;
		}
	}
close(FILE);
return 1;
}

=head2 write_env_file(file, &hash, [export])

Writes out a hash to a file in name='value' format, suitable for use in a shell
script. The parameters are :

=item file - Full path for a file to write to

=item hash - Hash reference of names and values to write.

=item export - If set to 1, prepend each variable setting with the word 'export'.

=cut
sub write_env_file
{
my $exp = $_[2] ? "export " : "";
&open_tempfile(FILE, ">$_[0]");
foreach my $k (keys %{$_[1]}) {
	my $v = $_[1]->{$k};
	if ($v =~ /^\S+$/) {
		&print_tempfile(FILE, "$exp$k=$v\n");
		}
	else {
		&print_tempfile(FILE, "$exp$k=\"$v\"\n");
		}
	}
&close_tempfile(FILE);
}

=head2 lock_file(filename, [readonly], [forcefile])

Lock a file for exclusive access. If the file is already locked, spin
until it is freed. Uses a .lock file, which is not 100% reliable, but seems
to work OK. The parameters are :

=item filename - File or directory to lock.

=item readonly - If set, the lock is for reading the file only. More than one script can have a readonly lock, but only one can hold a write lock.

=item forcefile - Force the file to be considered as a real file and not a symlink for Webmin actions logging purposes.

=cut
sub lock_file
{
my ($file, $readonly, $forcefile) = @_;
if ($file =~ /\r|\n|\0/) {
	&error("Lock filename contains invalid characters");
	}
my $realfile = &translate_filename($file);
return 0 if (!$file || defined($main::locked_file_list{$realfile}));
my $no_lock = !&can_lock_file($realfile);
my $lock_tries_count = 0;
my $last_lock_err;
while(1) {
	my $pid;
	if (!$no_lock && open(LOCKING, "$realfile.lock")) {
		$pid = <LOCKING>;
		$pid = int($pid);
		close(LOCKING);
		}
	if ($no_lock || !$pid || !kill(0, $pid) || $pid == $$) {
		# Got the lock!
		if (!$no_lock) {
			# Create the .lock file
			my $lockfile = $realfile.".lock";
			unlink($lockfile);
			open(LOCKING, ">$lockfile") || return 0;
			my $lck = eval "flock(LOCKING, 2+4)";
			my $err = $!;
			if (!$lck && !$@) {
				# Lock of lock file failed! Wait till later
				close(LOCKING);
				unlink($lockfile);
				$last_lock_err = "Flock failed : ".($@ || $err);
				goto tryagain;
				}
			my $ok = (print LOCKING $$,"\n");
			$err = $!;
			if (!$ok) {
				# Failed to write to .lock file ..
				close(LOCKING);
				unlink($lockfile);
				$last_lock_err = "Lock write failed : ".$err;
				goto tryagain;
				}
			eval "flock(LOCKING, 8)";
			$ok = close(LOCKING);
			$err = $!;
			if (!$ok) {
				# Failed to close lock file
				unlink($lockfile);
				$last_lock_err = "Lock close failed : ".$err;
				goto tryagain;
				}
			}
		$main::locked_file_list{$realfile} = int($readonly);
		push(@main::temporary_files, $lockfile);
		if (($gconfig{'logfiles'} || $gconfig{'logfullfiles'}) &&
		    !&get_module_variable('$no_log_file_changes') &&
		    !$readonly) {
			# Grab a copy of this file for later diffing
			my $lnk;
			$main::locked_file_data{$realfile} = undef;
			if (-d $realfile) {
				$main::locked_file_type{$realfile} = 1;
				$main::locked_file_data{$realfile} = '';
				}
			elsif (!$forcefile && ($lnk = readlink($realfile))) {
				$main::locked_file_type{$realfile} = 2;
				$main::locked_file_data{$realfile} = $lnk;
				}
			elsif (open(ORIGFILE, $realfile)) {
				$main::locked_file_type{$realfile} = 0;
				$main::locked_file_data{$realfile} = '';
				local $_;
				while(<ORIGFILE>) {
					$main::locked_file_data{$realfile} .=$_;
					}
				close(ORIGFILE);
				}
			}
		last;
		}
tryagain:
	sleep(1);
	if ($lock_tries_count++ > 5*60) {
		# Give up after 5 minutes
		&error(&text('elock_tries2', "<tt>$realfile</tt>", 5,
			     $last_lock_err));
		}
	}
return 1;
}

=head2 unlock_file(filename)

Release a lock on a file taken out by lock_file. If Webmin actions logging of
file changes is enabled, then at unlock file a diff will be taken between the
old and new contents, and stored under /var/webmin/diffs when webmin_log is
called. This can then be viewed in the Webmin Actions Log module.

=cut
sub unlock_file
{
my ($file) = @_;
my $realfile = &translate_filename($file);
return if (!$file || !defined($main::locked_file_list{$realfile}));
unlink("$realfile.lock") if (&can_lock_file($realfile));
delete($main::locked_file_list{$realfile});
if (exists($main::locked_file_data{$realfile})) {
	# Diff the new file with the old
	stat($realfile);
	my $lnk = readlink($realfile);
	my $type = -d _ ? 1 : $lnk ? 2 : 0;
	my $oldtype = $main::locked_file_type{$realfile};
	my $new = !defined($main::locked_file_data{$realfile});
	if ($new && !-e _) {
		# file doesn't exist, and never did! do nothing ..
		}
	elsif ($new && $type == 1 || !$new && $oldtype == 1) {
		# is (or was) a directory ..
		if (-d _ && !defined($main::locked_file_data{$realfile})) {
			push(@main::locked_file_diff,
			     { 'type' => 'mkdir', 'object' => $realfile });
			}
		elsif (!-d _ && defined($main::locked_file_data{$realfile})) {
			push(@main::locked_file_diff,
			     { 'type' => 'rmdir', 'object' => $realfile });
			}
		}
	elsif ($new && $type == 2 || !$new && $oldtype == 2) {
		# is (or was) a symlink ..
		if ($lnk && !defined($main::locked_file_data{$realfile})) {
			push(@main::locked_file_diff,
			     { 'type' => 'symlink', 'object' => $realfile,
			       'data' => $lnk });
			}
		elsif (!$lnk && defined($main::locked_file_data{$realfile})) {
			push(@main::locked_file_diff,
			     { 'type' => 'unsymlink', 'object' => $realfile,
			       'data' => $main::locked_file_data{$realfile} });
			}
		elsif ($lnk ne $main::locked_file_data{$realfile}) {
			push(@main::locked_file_diff,
			     { 'type' => 'resymlink', 'object' => $realfile,
			       'data' => $lnk });
			}
		}
	else {
		# is a file, or has changed type?!
		my ($diff, $delete_file);
		my $type = "modify";
		if (!-r _) {
			open(NEWFILE, ">$realfile");
			close(NEWFILE);
			$delete_file++;
			$type = "delete";
			}
		if (!defined($main::locked_file_data{$realfile})) {
			$type = "create";
			}
		open(ORIGFILE, ">$realfile.webminorig");
		print ORIGFILE $main::locked_file_data{$realfile};
		close(ORIGFILE);
		$diff = &backquote_command(
			"diff ".quotemeta("$realfile.webminorig")." ".
				quotemeta($realfile)." 2>/dev/null");
		push(@main::locked_file_diff,
		     { 'type' => $type, 'object' => $realfile,
		       'data' => $diff } ) if ($diff);
		unlink("$realfile.webminorig");
		unlink($realfile) if ($delete_file);
		}

	if ($gconfig{'logfullfiles'}) {
		# Add file details to list of those to fully log
		$main::orig_file_data{$realfile} ||=
			$main::locked_file_data{$realfile};
		$main::orig_file_type{$realfile} ||=
			$main::locked_file_type{$realfile};
		}

	delete($main::locked_file_data{$realfile});
	delete($main::locked_file_type{$realfile});
	}
}

=head2 test_lock(file)

Returns the PID if some file is currently locked, 0 if not.

=cut
sub test_lock
{
my ($file) = @_;
my $realfile = &translate_filename($file);
return 0 if (!$file);
return $$ if (defined($main::locked_file_list{$realfile}));
return 0 if (!&can_lock_file($realfile));
my $pid;
if (open(LOCKING, "$realfile.lock")) {
	$pid = <LOCKING>;
	$pid = int($pid);
	close(LOCKING);
	}
return $pid && kill(0, $pid) ? $pid : undef;
}

=head2 unlock_all_files

Unlocks all files locked by the current script.

=cut
sub unlock_all_files
{
foreach $f (keys %main::locked_file_list) {
	&unlock_file($f);
	}
}

=head2 can_lock_file(file)

Returns 1 if some file should be locked, based on the settings in the
Webmin Configuration module. For internal use by lock_file only.

=cut
sub can_lock_file
{
if (&is_readonly_mode()) {
	return 0;	# never lock in read-only mode
	}
elsif ($gconfig{'lockmode'} == 0) {
	return 1;	# always
	}
elsif ($gconfig{'lockmode'} == 1) {
	return 0;	# never
	}
else {
	# Check if under any of the directories
	my $match;
	foreach my $d (split(/\t+/, $gconfig{'lockdirs'})) {
		if (&same_file($d, $_[0]) ||
		    &is_under_directory($d, $_[0])) {
			$match = 1;
			}
		}
	return $gconfig{'lockmode'} == 2 ? $match : !$match;
	}
}

=head2 webmin_log(action, type, object, &params, [module], [host, script-on-host, client-ip])

Log some action taken by a user. This is typically called at the end of a
script, once all file changes are complete and all commands run. The
parameters are :

=item action - A short code for the action being performed, like 'create'.

=item type - A code for the type of object the action is performed to, like 'user'.

=item object - A short name for the object, like 'joe' if the Unix user 'joe' was just created.

=item params - A hash ref of additional information about the action.

=item module - Name of the module in which the action was performed, which defaults to the current module.

=item host - Remote host on which the action was performed. You should never need to set this (or the following two parameters), as they are used only for remote Webmin logging.

=item script-on-host - Script name like create_user.cgi on the host the action was performed on.

=item client-ip - IP address of the browser that performed the action.

=cut
sub webmin_log
{
return if (!$gconfig{'log'} || &is_readonly_mode());
my $m = $_[4] ? $_[4] : &get_module_name();

if ($gconfig{'logclear'}) {
	# check if it is time to clear the log
	my @st = stat("$webmin_logfile.time");
	my $write_logtime = 0;
	if (@st) {
		if ($st[9]+$gconfig{'logtime'}*60*60 < time()) {
			# clear logfile and all diff files
			&unlink_file("$ENV{'WEBMIN_VAR'}/diffs");
			&unlink_file("$ENV{'WEBMIN_VAR'}/files");
			&unlink_file("$ENV{'WEBMIN_VAR'}/annotations");
			unlink($webmin_logfile);
			$write_logtime = 1;
			}
		}
	else {
		$write_logtime = 1;
		}
	if ($write_logtime) {
		open(LOGTIME, ">$webmin_logfile.time");
		print LOGTIME time(),"\n";
		close(LOGTIME);
		}
	}

# If an action script directory is defined, call the appropriate scripts
if ($gconfig{'action_script_dir'}) {
	my ($action, $type, $object) = ($_[0], $_[1], $_[2]);
	my ($basedir) = $gconfig{'action_script_dir'};
	for my $dir ("$basedir/$type/$action", "$basedir/$type", $basedir) {
		next if (!-d $dir);
		my ($file);
		opendir(DIR, $dir) or die "Can't open $dir: $!";
		while (defined($file = readdir(DIR))) {
			next if ($file =~ /^\.\.?$/); # skip . and ..
			next if (!-x "$dir/$file");
			my %OLDENV = %ENV;
			$ENV{'ACTION_MODULE'} = &get_module_name();
			$ENV{'ACTION_ACTION'} = $_[0];
			$ENV{'ACTION_TYPE'} = $_[1];
			$ENV{'ACTION_OBJECT'} = $_[2];
			$ENV{'ACTION_SCRIPT'} = $script_name;
			foreach my $p (keys %param) {
			    $ENV{'ACTION_PARAM_'.uc($p)} = $param{$p};
			    }
			system("$dir/$file", @_,
			   "<$null_file", ">$null_file", "2>&1");
			%ENV = %OLDENV;
			}
		}
	}

# should logging be done at all?
return if ($gconfig{'logusers'} && &indexof($base_remote_user,
	   split(/\s+/, $gconfig{'logusers'})) < 0);
return if ($gconfig{'logmodules'} && &indexof($m,
	   split(/\s+/, $gconfig{'logmodules'})) < 0);

# log the action
my $now = time();
my @tm = localtime($now);
my $script_name = $0 =~ /([^\/]+)$/ ? $1 : '-';
my $id = sprintf "%d.%d.%d", $now, $$, $main::action_id_count;
my $idprefix = substr($now, 0, 5);
$main::action_id_count++;
my $line = sprintf "%s [%2.2d/%s/%4.4d %2.2d:%2.2d:%2.2d] %s %s %s %s %s \"%s\" \"%s\" \"%s\"",
	$id, $tm[3], ucfirst($number_to_month_map{$tm[4]}), $tm[5]+1900,
	$tm[2], $tm[1], $tm[0],
	$remote_user || '-',
	$main::session_id || '-',
	$_[7] || $ENV{'REMOTE_HOST'} || '-',
	$m, $_[5] ? "$_[5]:$_[6]" : $script_name,
	$_[0], $_[1] ne '' ? $_[1] : '-', $_[2] ne '' ? $_[2] : '-';
my %param;
foreach my $k (sort { $a cmp $b } keys %{$_[3]}) {
	my $v = $_[3]->{$k};
	my @pv;
	if ($v eq '') {
		$line .= " $k=''";
		@rv = ( "" );
		}
	elsif (ref($v) eq 'ARRAY') {
		foreach $vv (@$v) {
			next if (ref($vv));
			push(@pv, $vv);
			$vv =~ s/(['"\\\r\n\t\%])/sprintf("%%%2.2X",ord($1))/ge;
			$line .= " $k='$vv'";
			}
		}
	elsif (!ref($v)) {
		foreach $vv (split(/\0/, $v)) {
			push(@pv, $vv);
			$vv =~ s/(['"\\\r\n\t\%])/sprintf("%%%2.2X",ord($1))/ge;
			$line .= " $k='$vv'";
			}
		}
	$param{$k} = join(" ", @pv);
	}
open(WEBMINLOG, ">>$webmin_logfile");
print WEBMINLOG $line,"\n";
close(WEBMINLOG);
if ($gconfig{'logperms'}) {
	chmod(oct($gconfig{'logperms'}), $webmin_logfile);
	}
else {
	chmod(0600, $webmin_logfile);
	}

if ($gconfig{'logfiles'} && !&get_module_variable('$no_log_file_changes')) {
	# Find and record the changes made to any locked files, or commands run
	my $i = 0;
	mkdir("$ENV{'WEBMIN_VAR'}/diffs", 0700);
	foreach my $d (@main::locked_file_diff) {
		mkdir("$ENV{'WEBMIN_VAR'}/diffs/$idprefix", 0700);
		mkdir("$ENV{'WEBMIN_VAR'}/diffs/$idprefix/$id", 0700);
		open(DIFFLOG, ">$ENV{'WEBMIN_VAR'}/diffs/$idprefix/$id/$i");
		print DIFFLOG "$d->{'type'} $d->{'object'}\n";
		print DIFFLOG $d->{'data'};
		close(DIFFLOG);
		if ($d->{'input'}) {
			open(DIFFLOG,
			  ">$ENV{'WEBMIN_VAR'}/diffs/$idprefix/$id/$i.input");
			print DIFFLOG $d->{'input'};
			close(DIFFLOG);
			}
		if ($gconfig{'logperms'}) {
			chmod(oct($gconfig{'logperms'}),
			     "$ENV{'WEBMIN_VAR'}/diffs/$idprefix/$id/$i",
			     "$ENV{'WEBMIN_VAR'}/diffs/$idprefix/$id/$i.input");
			}
		$i++;
		}
	@main::locked_file_diff = undef;
	}

if ($gconfig{'logfullfiles'}) {
	# Save the original contents of any modified files
	my $i = 0;
	mkdir("$ENV{'WEBMIN_VAR'}/files", 0700);
	foreach my $f (keys %main::orig_file_data) {
		mkdir("$ENV{'WEBMIN_VAR'}/files/$idprefix", 0700);
		mkdir("$ENV{'WEBMIN_VAR'}/files/$idprefix/$id", 0700);
		open(ORIGLOG, ">$ENV{'WEBMIN_VAR'}/files/$idprefix/$id/$i");
		if (!defined($main::orig_file_type{$f})) {
			print ORIGLOG -1," ",$f,"\n";
			}
		else {
			print ORIGLOG $main::orig_file_type{$f}," ",$f,"\n";
			}
		print ORIGLOG $main::orig_file_data{$f};
		close(ORIGLOG);
		if ($gconfig{'logperms'}) {
			chmod(oct($gconfig{'logperms'}),
			      "$ENV{'WEBMIN_VAR'}/files/$idprefix/$id.$i");
			}
		$i++;
		}
	%main::orig_file_data = undef;
	%main::orig_file_type = undef;
	}

if ($miniserv::page_capture_out) {
	# Save the whole page output
	mkdir("$ENV{'WEBMIN_VAR'}/output", 0700);
	mkdir("$ENV{'WEBMIN_VAR'}/output/$idprefix", 0700);
	open(PAGEOUT, ">$ENV{'WEBMIN_VAR'}/output/$idprefix/$id");
	print PAGEOUT $miniserv::page_capture_out;
	close(PAGEOUT);
	if ($gconfig{'logperms'}) {
		chmod(oct($gconfig{'logperms'}),
		      "$ENV{'WEBMIN_VAR'}/output/$idprefix/$id");
		}
	$miniserv::page_capture_out = undef;
	}

# Convert params to a format usable by parse_webmin_log
my %params;
foreach my $k (keys %{$_[3]}) {
	my $v = $_[3]->{$k};
	if (ref($v) eq 'ARRAY') {
		$params{$k} = join("\0", @$v);
		}
	else {
		$params{$k} = $v;
		}
	}

# Construct description if one is needed
my $logemail = $gconfig{'logemail'} &&
	       (!$gconfig{'logmodulesemail'} ||
	        &indexof($m, split(/\s+/, $gconfig{'logmodulesemail'})) >= 0) &&
	       &foreign_check("mailboxes");
my $msg = undef;
my %minfo = &get_module_info($m);
if ($logemail || $gconfig{'logsyslog'}) {
	my $mod = &get_module_name();
	my $mdir = module_root_directory($mod);
	if (&foreign_check("webminlog")) {
		&foreign_require("webminlog");
		my $act = &webminlog::parse_logline($line);
		$msg = &webminlog::get_action_description($act, 0);
		$msg =~ s/<[^>]*>//g;	# Remove tags
		}
	$msg ||= "$_[0] $_[1] $_[2]";
	}

# Log to syslog too
if ($gconfig{'logsyslog'}) {
	eval 'use Sys::Syslog qw(:DEFAULT setlogsock);
	      openlog(&get_product_name(), "cons,pid,ndelay", "daemon");
	      setlogsock("inet");';
	if (!$@) {
		eval { syslog("info", "%s", "[$minfo{'desc'}] $msg"); };
		}
	}

# Log to email, if enabled and for this module
if ($logemail) {
	# Construct an email message
	&foreign_require("mailboxes");
	my $mdesc;
	if ($m && $m ne "global") {
		$mdesc = $minfo{'desc'} || $m;
		}
	my $body = $text{'log_email_desc'}."\n\n";
	$body .= &text('log_email_mod', $m || "global")."\n";
	if ($mdesc) {
		$body .= &text('log_email_moddesc', $mdesc)."\n";
		}
	$body .= &text('log_email_time', &make_date(time()))."\n";
	$body .= &text('log_email_system', &get_display_hostname())."\n";
	$body .= &text('log_email_user', $remote_user)."\n";
	$body .= &text('log_email_remote', $_[7] || $ENV{'REMOTE_HOST'})."\n";
	$body .= &text('log_email_script', $script_name)."\n";
	if ($main::session_id) {
		$body .= &text('log_email_session', $main::session_id)."\n";
		}
	$body .= "\n";
	$body .= $msg."\n";
	&mailboxes::send_text_mail(
		&mailboxes::get_from_address(),
		$gconfig{'logemail'},
		undef,
		$mdesc ? &text('log_email_subject', $mdesc)
		       : $text{'log_email_global'},
		$body);
	}
}

=head2 additional_log(type, object, data, [input])

Records additional log data for an upcoming call to webmin_log, such
as a command that was run or SQL that was executed. Typically you will never
need to call this function directory.

=cut
sub additional_log
{
if ($gconfig{'logfiles'} && !&get_module_variable('$no_log_file_changes')) {
	push(@main::locked_file_diff,
	     { 'type' => $_[0], 'object' => $_[1], 'data' => $_[2],
	       'input' => $_[3] } );
	}
}

=head2 webmin_debug_log(type, message)

Write something to the Webmin debug log. For internal use only.

=cut
sub webmin_debug_log
{
my ($type, $msg) = @_;
return 0 if (!$main::opened_debug_log);
return 0 if ($gconfig{'debug_no'.$main::webmin_script_type});
if ($gconfig{'debug_modules'}) {
	my @dmods = split(/\s+/, $gconfig{'debug_modules'});
	return 0 if (&indexof($main::initial_module_name, @dmods) < 0);
	}
my $now;
eval 'use Time::HiRes qw(gettimeofday); ($now, $ms) = gettimeofday';
$now ||= time();
my @tm = localtime($now);
my $line = sprintf
	"%s [%2.2d/%s/%4.4d %2.2d:%2.2d:%2.2d.%6.6d] %s %s %s %s \"%s\"",
        $$, $tm[3], ucfirst($number_to_month_map{$tm[4]}), $tm[5]+1900,
        $tm[2], $tm[1], $tm[0], $ms,
	$remote_user || "-",
	$ENV{'REMOTE_HOST'} || "-",
	&get_module_name() || "-",
	$type,
	$msg;
seek(main::DEBUGLOG, 0, 2);
print main::DEBUGLOG $line."\n";
return 1;
}

=head2 system_logged(command)

Just calls the Perl system() function, but also logs the command run.

=cut
sub system_logged
{
if (&is_readonly_mode()) {
	print STDERR "Vetoing command $_[0]\n";
	return 0;
	}
my @realcmd = ( &translate_command($_[0]), @_[1..$#_] );
my $cmd = join(" ", @realcmd);
my $and;
if ($cmd =~ s/(\s*&\s*)$//) {
	$and = $1;
	}
while($cmd =~ s/(\d*)(<|>)((\/(tmp|dev)\S+)|&\d+)\s*$//) { }
$cmd =~ s/^\((.*)\)\s*$/$1/;
$cmd .= $and;
&additional_log('exec', undef, $cmd);
return system(@realcmd);
}

=head2 backquote_logged(command)

Executes a command and returns the output (like `command`), but also logs it.

=cut
sub backquote_logged
{
if (&is_readonly_mode()) {
	$? = 0;
	print STDERR "Vetoing command $_[0]\n";
	return undef;
	}
my $realcmd = &translate_command($_[0]);
my $cmd = $realcmd;
my $and;
if ($cmd =~ s/(\s*&\s*)$//) {
	$and = $1;
	}
while($cmd =~ s/(\d*)(<|>)((\/(tmp\/.webmin|dev)\S+)|&\d+)\s*$//) { }
$cmd =~ s/^\((.*)\)\s*$/$1/;
$cmd .= $and;
&additional_log('exec', undef, $cmd);
&webmin_debug_log('CMD', "cmd=$cmd") if ($gconfig{'debug_what_cmd'});
if ($realcmd !~ /;|\&\&|\|/ && $realcmd !~ /^\s*\(/) {
	# Force run in shell, to get useful output if command doesn't exist
	$realcmd = "($realcmd)";
	}
return `$realcmd`;
}

=head2 backquote_with_timeout(command, timeout, safe?, [maxlines])

Runs some command, waiting at most the given number of seconds for it to
complete, and returns the output. The maxlines parameter sets the number
of lines of output to capture. The safe parameter should be set to 1 if the
command is safe for read-only mode users to run.

=cut
sub backquote_with_timeout
{
my $realcmd = &translate_command($_[0]);
my $out;
my $pid = &open_execute_command(OUT, "($realcmd) <$null_file", 1, $_[2]);
my $start = time();
my $timed_out = 0;
my $linecount = 0;
while(1) {
	my $elapsed = time() - $start;
	last if ($elapsed > $_[1]);
	my $rmask;
	vec($rmask, fileno(OUT), 1) = 1;
	my $sel = select($rmask, undef, undef, $_[1] - $elapsed);
	last if (!$sel || $sel < 0);
	my $line = <OUT>;
	last if (!defined($line));
	$out .= $line;
	$linecount++;
	if ($_[3] && $linecount >= $_[3]) {
		# Got enough lines
		last;
		}
	}
if (kill('TERM', $pid) && time() - $start >= $_[1]) {
	$timed_out = 1;
	}
close(OUT);
return wantarray ? ($out, $timed_out) : $out;
}

=head2 backquote_command(command, safe?)

Executes a command and returns the output (like `command`), subject to
command translation. The safe parameter should be set to 1 if the command
is safe for read-only mode users to run.

=cut
sub backquote_command
{
if (&is_readonly_mode() && !$_[1]) {
	print STDERR "Vetoing command $_[0]\n";
	$? = 0;
	return undef;
	}
my $realcmd = &translate_command($_[0]);
&webmin_debug_log('CMD', "cmd=$realcmd") if ($gconfig{'debug_what_cmd'});
if ($realcmd !~ /;|\&\&|\|/ && $realcmd !~ /^\s*\(/) {
	# Force run in shell, to get useful output if command doesn't exist
	$realcmd = "($realcmd)";
	}
return `$realcmd`;
}

=head2 kill_logged(signal, pid, ...)

Like Perl's built-in kill function, but also logs the fact that some process
was killed. On Windows, falls back to calling process.exe to terminate a
process.

=cut
sub kill_logged
{
return scalar(@_)-1 if (&is_readonly_mode());
&webmin_debug_log('KILL', "signal=$_[0] pids=".join(" ", @_[1..@_-1]))
	if ($gconfig{'debug_what_procs'});
&additional_log('kill', $_[0], join(" ", @_[1..@_-1])) if (@_ > 1);
if ($gconfig{'os_type'} eq 'windows') {
	# Emulate some kills with process.exe
	my $arg = $_[0] eq "KILL" ? "-k" :
		  $_[0] eq "TERM" ? "-q" :
		  $_[0] eq "STOP" ? "-s" :
		  $_[0] eq "CONT" ? "-r" : undef;
	my $ok = 0;
	foreach my $p (@_[1..@_-1]) {
		if ($p < 0) {
			$ok ||= kill($_[0], $p);
			}
		elsif ($arg) {
			&execute_command("process $arg $p");
			$ok = 1;
			}
		}
	return $ok;
	}
else {
	# Normal Unix kill
	return kill(@_);
	}
}

=head2 rename_logged(old, new)

Re-names a file and logs the rename. If the old and new files are on different
filesystems, calls mv or the Windows rename function to do the job.

=cut
sub rename_logged
{
&additional_log('rename', $_[0], $_[1]) if ($_[0] ne $_[1]);
return &rename_file($_[0], $_[1]);
}

=head2 rename_file(old, new)

Renames a file or directory. If the old and new files are on different
filesystems, calls mv or the Windows rename function to do the job.

=cut
sub rename_file
{
if (&is_readonly_mode()) {
	print STDERR "Vetoing rename from $_[0] to $_[1]\n";
	return 1;
	}
my $src = &translate_filename($_[0]);
my $dst = &translate_filename($_[1]);
&webmin_debug_log('RENAME', "src=$src dst=$dst")
	if ($gconfig{'debug_what_ops'});
my $ok = rename($src, $dst);
if (!$ok && $! !~ /permission/i) {
	# Try the mv command, in case this is a cross-filesystem rename
	if ($gconfig{'os_type'} eq 'windows') {
		# Need to use rename
		my $out = &backquote_command("rename ".quotemeta($_[0]).
					     " ".quotemeta($_[1])." 2>&1");
		$ok = !$?;
		$! = $out if (!$ok);
		}
	else {
		# Can use mv
		my $out = &backquote_command("mv ".quotemeta($_[0]).
					     " ".quotemeta($_[1])." 2>&1");
		$ok = !$?;
		$! = $out if (!$ok);
		}
	}
return $ok;
}

=head2 symlink_logged(src, dest)

Create a symlink, and logs it. Effectively does the same thing as the Perl
symlink function.

=cut
sub symlink_logged
{
&lock_file($_[1]);
my $rv = &symlink_file($_[0], $_[1]);
&unlock_file($_[1]);
return $rv;
}

=head2 symlink_file(src, dest)

Creates a soft link, unless in read-only mode. Effectively does the same thing
as the Perl symlink function.

=cut
sub symlink_file
{
if (&is_readonly_mode()) {
	print STDERR "Vetoing symlink from $_[0] to $_[1]\n";
	return 1;
	}
my $src = &translate_filename($_[0]);
my $dst = &translate_filename($_[1]);
&webmin_debug_log('SYMLINK', "src=$src dst=$dst")
	if ($gconfig{'debug_what_ops'});
return symlink($src, $dst);
}

=head2 link_file(src, dest)

Creates a hard link, unless in read-only mode. The existing new link file
will be deleted if necessary. Effectively the same as Perl's link function.

=cut
sub link_file
{
if (&is_readonly_mode()) {
	print STDERR "Vetoing link from $_[0] to $_[1]\n";
	return 1;
	}
my $src = &translate_filename($_[0]);
my $dst = &translate_filename($_[1]);
&webmin_debug_log('LINK', "src=$src dst=$dst")
	if ($gconfig{'debug_what_ops'});
unlink($dst);			# make sure link works
return link($src, $dst);
}

=head2 make_dir(dir, perms, recursive)

Creates a directory and sets permissions on it, unless in read-only mode.
The perms parameter sets the octal permissions to apply, which unlike Perl's
mkdir will really get set. The recursive flag can be set to 1 to have the
function create parent directories too.

=cut
sub make_dir
{
my ($dir, $perms, $recur) = @_;
if (&is_readonly_mode()) {
	print STDERR "Vetoing directory $dir\n";
	return 1;
	}
$dir = &translate_filename($dir);
my $exists = -d $dir ? 1 : 0;
return 1 if ($exists && $recur);	# already exists
&webmin_debug_log('MKDIR', $dir) if ($gconfig{'debug_what_ops'});
my $rv = mkdir($dir, $perms);
if (!$rv && $recur) {
	# Failed .. try mkdir -p
	my $param = $gconfig{'os_type'} eq 'windows' ? "" : "-p";
	my $ex = &execute_command("mkdir $param ".&quote_path($dir));
	if ($ex) {
		return 0;
		}
	}
if (!$exists) {
	chmod($perms, $dir);
	}
return 1;
}

=head2 set_ownership_permissions(user, group, perms, file, ...)

Sets the user, group owner and permissions on some files. The parameters are :

=item user - UID or username to change the file owner to. If undef, then the owner is not changed.

=item group - GID or group name to change the file group to. If undef, then the group is set to the user's primary group.

=item perms - Octal permissions set to set on the file. If undef, they are left alone.

=item file - One or more files or directories to modify.

=cut
sub set_ownership_permissions
{
my ($user, $group, $perms, @files) = @_;
if (&is_readonly_mode()) {
	print STDERR "Vetoing permission changes on ",join(" ", @files),"\n";
	return 1;
	}
@files = map { &translate_filename($_) } @files;
if ($gconfig{'debug_what_ops'}) {
	foreach my $f (@files) {
		&webmin_debug_log('PERMS',
			"file=$f user=$user group=$group perms=$perms");
		}
	}
my $rv = 1;
if (defined($user)) {
	my $uid = $user !~ /^\d+$/ ? getpwnam($user) : $user;
	my $gid;
	if (defined($group)) {
		$gid = $group !~ /^\d+$/ ? getgrnam($group) : $group;
		}
	else {
		my @uinfo = getpwuid($uid);
		$gid = $uinfo[3];
		}
	$rv = chown($uid, $gid, @files);
	}
if ($rv && defined($perms)) {
	$rv = chmod($perms, @files);
	}
return $rv;
}

=head2 unlink_logged(file, ...)

Like Perl's unlink function, but locks the files beforehand and un-locks them
after so that the deletion is logged by Webmin.

=cut
sub unlink_logged
{
my %locked;
foreach my $f (@_) {
	if (!&test_lock($f)) {
		&lock_file($f);
		$locked{$f} = 1;
		}
	}
my @rv = &unlink_file(@_);
foreach my $f (@_) {
	if ($locked{$f}) {
		&unlock_file($f);
		}
	}
return wantarray ? @rv : $rv[0];
}

=head2 unlink_file(file, ...)

Deletes some files or directories. Like Perl's unlink function, but also
recursively deletes directories with the rm command if needed.

=cut
sub unlink_file
{
return 1 if (&is_readonly_mode());
my $rv = 1;
my $err;
foreach my $f (@_) {
	&unflush_file_lines($f);
	my $realf = &translate_filename($f);
	&webmin_debug_log('UNLINK', $realf) if ($gconfig{'debug_what_ops'});
	if (-d $realf) {
		if (!rmdir($realf)) {
			my $out;
			if ($gconfig{'os_type'} eq 'windows') {
				# Call del and rmdir commands
				my $qm = $realf;
				$qm =~ s/\//\\/g;
				my $out = `del /q "$qm" 2>&1`;
				if (!$?) {
					$out = `rmdir "$qm" 2>&1`;
					}
				}
			else {
				# Use rm command
				my $qm = quotemeta($realf);
				$out = `rm -rf $qm 2>&1`;
				}
			if ($?) {
				$rv = 0;
				$err = $out;
				}
			}
		}
	else {
		if (!unlink($realf)) {
			$rv = 0;
			$err = $!;
			}
		}
	}
return wantarray ? ($rv, $err) : $rv;
}

=head2 copy_source_dest(source, dest, [copy-link-target])

Copy some file or directory to a new location. Returns 1 on success, or 0
on failure - also sets $! on failure. If the source is a directory, uses
piped tar commands to copy a whole directory structure including permissions
and special files.

=cut
sub copy_source_dest
{
return (1, undef) if (&is_readonly_mode());
my ($src, $dst, $copylink) = @_;
my $ok = 1;
my ($err, $out);
&webmin_debug_log('COPY', "src=$src dst=$dst")
	if ($gconfig{'debug_what_ops'});
if ($gconfig{'os_type'} eq 'windows') {
	# No tar or cp on windows, so need to use copy command
	$src =~ s/\//\\/g;
	$dst =~ s/\//\\/g;
	if (-d $src) {
		$out = &backquote_logged("xcopy \"$src\" \"$dst\" /Y /E /I 2>&1");
		}
	else {
		$out = &backquote_logged("copy /Y \"$src\" \"$dst\" 2>&1");
		}
	if ($?) {
		$ok = 0;
		$err = $out;
		}
	}
elsif (-d $src) {
	# A directory .. need to copy with tar command
	my @st = stat($src);
	unlink($dst);
	mkdir($dst, 0755);
	&set_ownership_permissions($st[4], $st[5], $st[2], $dst);
	$out = &backquote_logged("(cd ".quotemeta($src)." ; tar cf - . | (cd ".quotemeta($dst)." ; tar xf -)) 2>&1");
	if ($?) {
		$ok = 0;
		$err = $out;
		}
	}
elsif (-l $src && !$copylink) {
	# A link .. re-create
	my $linkdst = readlink($src);
	$ok = &symlink_logged($linkdst, $dst);
	$err = $ok ? undef : $!;
	}
else {
	# Can just copy with cp
	my $out = &backquote_logged("cp -p ".quotemeta($src).
				    " ".quotemeta($dst)." 2>&1");
	if ($?) {
		$ok = 0;
		$err = $out;
		}
	}
return wantarray ? ($ok, $err) : $ok;
}

=head2 remote_session_name(host|&server)

Generates a session ID for some server. For this server, this will always
be an empty string. For a server object it will include the hostname and
port and PID. For a server name, it will include the hostname and PID. For
internal use only.

=cut
sub remote_session_name
{
return ref($_[0]) && $_[0]->{'host'} && $_[0]->{'port'} ?
		"$_[0]->{'host'}:$_[0]->{'port'}.$$" :
       $_[0] eq "" || ref($_[0]) && $_[0]->{'id'} == 0 ? "" :
       ref($_[0]) ? "" : "$_[0].$$";
}

=head2 remote_foreign_require(server, module, file)

Connects to rpc.cgi on a remote webmin server and have it open a session
to a process that will actually do the require and run functions. This is the
equivalent for foreign_require, but for a remote Webmin system. The server
parameter can either be a hostname of a system registered in the Webmin
Servers Index module, or a hash reference for a system from that module.

=cut
sub remote_foreign_require
{
my $call = { 'action' => 'require',
	     'module' => $_[1],
	     'file' => $_[2] };
my $sn = &remote_session_name($_[0]);
if ($remote_session{$sn}) {
	$call->{'session'} = $remote_session{$sn};
	}
else {
	$call->{'newsession'} = 1;
	}
my $rv = &remote_rpc_call($_[0], $call);
if ($rv->{'session'}) {
	$remote_session{$sn} = $rv->{'session'};
	$remote_session_server{$sn} = $_[0];
	}
}

=head2 remote_foreign_call(server, module, function, [arg]*)

Call a function on a remote server. Must have been setup first with
remote_foreign_require for the same server and module. Equivalent to
foreign_call, but with the extra server parameter to specify the remote
system's hostname.

=cut
sub remote_foreign_call
{
return undef if (&is_readonly_mode());
my $sn = &remote_session_name($_[0]);
return &remote_rpc_call($_[0], { 'action' => 'call',
				 'module' => $_[1],
				 'func' => $_[2],
				 'session' => $remote_session{$sn},
				 'args' => [ @_[3 .. $#_] ] } );
}

=head2 remote_foreign_check(server, module, [api-only])

Checks if some module is installed and supported on a remote server. Equivalent
to foreign_check, but for the remote Webmin system specified by the server
parameter.

=cut
sub remote_foreign_check
{
return &remote_rpc_call($_[0], { 'action' => 'check',
				 'module' => $_[1],
				 'api' => $_[2] });
}

=head2 remote_foreign_config(server, module)

Gets the configuration for some module from a remote server, as a hash ref.
Equivalent to foreign_config, but for a remote system.

=cut
sub remote_foreign_config
{
return &remote_rpc_call($_[0], { 'action' => 'config',
				 'module' => $_[1] });
}

=head2 remote_eval(server, module, code)

Evaluates some perl code in the context of a module on a remote webmin server.
The server parameter must be the hostname of a remote system, module must
be a module directory name, and code a string of Perl code to run. This can
only be called after remote_foreign_require for the same server and module.

=cut
sub remote_eval
{
return undef if (&is_readonly_mode());
my $sn = &remote_session_name($_[0]);
return &remote_rpc_call($_[0], { 'action' => 'eval',
				 'module' => $_[1],
				 'code' => $_[2],
				 'session' => $remote_session{$sn} });
}

=head2 remote_write(server, localfile, [remotefile], [remotebasename])

Transfers some local file to another server via Webmin's RPC protocol, and
returns the resulting remote filename. If the remotefile parameter is given,
that is the destination filename which will be used. Otherwise a randomly
selected temporary filename will be used, and returned by the function.

=cut
sub remote_write
{
my ($host, $localfile, $remotefile, $remotebase) = @_;
return undef if (&is_readonly_mode());
my ($data, $got);
my $rv = &remote_rpc_call($host, { 'action' => 'tcpwrite',
				   'file' => $remotefile,
				   'name' => $remotebase } );
my $error;
my $serv = ref($host) ? $host->{'host'} : $host;
&open_socket($serv || "localhost", $rv->[1], TWRITE, \$error);
return &$main::remote_error_handler("Failed to transfer file : $error")
	if ($error);
open(FILE, $localfile);
while(read(FILE, $got, 1024) > 0) {
	print TWRITE $got;
	}
close(FILE);
shutdown(TWRITE, 1);
$error = <TWRITE>;
if ($error && $error !~ /^OK/) {
	# Got back an error!
	return &$main::remote_error_handler("Failed to transfer file : $error");
	}
close(TWRITE);
return $rv->[0];
}

=head2 remote_read(server, localfile, remotefile)

Transfers a file from a remote server to this system, using Webmin's RPC
protocol. The server parameter must be the hostname of a system registered
in the Webmin Servers Index module, localfile is the destination path on this
system, and remotefile is the file to fetch from the remote server.

=cut
sub remote_read
{
my ($host, $localfile, $remotefile) = @_;
my $rv = &remote_rpc_call($host, { 'action' => 'tcpread',
				   'file' => $remotefile } );
if (!$rv->[0]) {
	return &$main::remote_error_handler("Failed to transfer file : $rv->[1]");
	}
my $error;
my $serv = ref($host) ? $host->{'host'} : $host;
&open_socket($serv || "localhost", $rv->[1], TREAD, \$error);
return &$main::remote_error_handler("Failed to transfer file : $error")
	if ($error);
my $got;
open(FILE, ">$localfile");
while(read(TREAD, $got, 1024) > 0) {
	print FILE $got;
	}
close(FILE);
close(TREAD);
}

=head2 remote_finished

Close all remote sessions. This happens automatically after a while
anyway, but this function should be called to clean things up faster.

=cut
sub remote_finished
{
foreach my $sn (keys %remote_session) {
	my $server = $remote_session_server{$sn};
	&remote_rpc_call($server, { 'action' => 'quit',
			            'session' => $remote_session{$sn} } );
	delete($remote_session{$sn});
	delete($remote_session_server{$sn});
	}
foreach my $fh (keys %fast_fh_cache) {
	close($fh);
	delete($fast_fh_cache{$fh});
	}
}

=head2 remote_error_setup(&function)

Sets a function to be called instead of &error when a remote RPC operation
fails. Useful if you want to have more control over your remote operations.

=cut
sub remote_error_setup
{
$main::remote_error_handler = $_[0] || \&error;
}

=head2 remote_rpc_call(server, &structure)

Calls rpc.cgi on some server and passes it a perl structure (hash,array,etc)
and then reads back a reply structure. This is mainly for internal use only,
and is called by the other remote_* functions.

=cut
sub remote_rpc_call
{
my $serv;
my $sn = &remote_session_name($_[0]);	# Will be undef for local connection
if (ref($_[0])) {
	# Server structure was given
	$serv = $_[0];
	$serv->{'user'} || $serv->{'id'} == 0 ||
		return &$main::remote_error_handler(
			"No Webmin login set for server");
	}
elsif ($_[0]) {
	# lookup the server in the webmin servers module if needed
	if (!%main::remote_servers_cache) {
		&foreign_require("servers");
		foreach $s (&foreign_call("servers", "list_servers")) {
			$main::remote_servers_cache{$s->{'host'}} = $s;
			$main::remote_servers_cache{$s->{'host'}.":".$s->{'port'}} = $s;
			}
		}
	$serv = $main::remote_servers_cache{$_[0]};
	$serv || return &$main::remote_error_handler(
				"No Webmin Servers entry for $_[0]");
	$serv->{'user'} || return &$main::remote_error_handler(
				"No login set for server $_[0]");
	}
my $ip = $serv->{'ip'} || $serv->{'host'};

# Work out the username and password
my ($user, $pass);
if ($serv->{'sameuser'}) {
	$user = $remote_user;
	defined($main::remote_pass) || return &$main::remote_error_handler(
				   "Password for this server is not available");
	$pass = $main::remote_pass;
	}
else {
	$user = $serv->{'user'};
	$pass = $serv->{'pass'};
	}

if ($serv->{'fast'} || !$sn) {
	# Make TCP connection call to fastrpc.cgi
	if (!$fast_fh_cache{$sn} && $sn) {
		# Need to open the connection
		my $reqs;
		if ($serv->{'checkssl'}) {
			$reqs = { 'host' => 1,
				  'checkhost' => $serv->{'host'},
				  'self' => 1 };
			my %sconfig = &foreign_config("servers");
			if ($sconfig{'capath'}) {
				$reqs->{'capath'} = $sconfig{'capath'};
				}
			}
		my $con = &make_http_connection(
			$ip, $serv->{'port'}, $serv->{'ssl'},
			"POST", "/fastrpc.cgi", undef, undef, $reqs);
		return &$main::remote_error_handler(
		    "Failed to connect to $serv->{'host'} : $con")
			if (!ref($con));
		&write_http_connection($con, "Host: $serv->{'host'}\r\n");
		&write_http_connection($con, "User-agent: Webmin\r\n");
		my $auth = &encode_base64("$user:$pass");
		$auth =~ tr/\n//d;
		&write_http_connection($con, "Authorization: basic $auth\r\n");
		&write_http_connection($con, "Content-length: ",
					     length($tostr),"\r\n");
		&write_http_connection($con, "\r\n");
		&write_http_connection($con, $tostr);

		# read back the response
		my $line = &read_http_connection($con);
		$line =~ tr/\r\n//d;
		if ($line =~ /^HTTP\/1\..\s+401\s+/) {
			return &$main::remote_error_handler("Login to RPC server as $user rejected");
			}
		$line =~ /^HTTP\/1\..\s+200\s+/ ||
			return &$main::remote_error_handler("HTTP error : $line");
		do {
			$line = &read_http_connection($con);
			$line =~ tr/\r\n//d;
			} while($line);
		$line = &read_http_connection($con);
		if ($line =~ /^0\s+(.*)/) {
			return &$main::remote_error_handler("RPC error : $1");
			}
		elsif ($line =~ /^1\s+(\S+)\s+(\S+)\s+(\S+)/ ||
		       $line =~ /^1\s+(\S+)\s+(\S+)/) {
			# Started ok .. connect and save SID
			&close_http_connection($con);
			my ($port, $sid, $version, $error) = ($1, $2, $3);
			&open_socket($ip, $port, $sid, \$error);
			return &$main::remote_error_handler("Failed to connect to fastrpc.cgi : $error")
				if ($error);
			$fast_fh_cache{$sn} = $sid;
			$remote_server_version{$sn} = $version;
			}
		else {
			while($stuff = &read_http_connection($con)) {
				$line .= $stuff;
				}
			return &$main::remote_error_handler(
				"Bad response from fastrpc.cgi : $line");
			}
		}
	elsif (!$fast_fh_cache{$sn}) {
		# Open the connection by running fastrpc.cgi locally
		pipe(RPCOUTr, RPCOUTw);
		if (!fork()) {
			untie(*STDIN);
			untie(*STDOUT);
			open(STDOUT, ">&RPCOUTw");
			close(STDIN);
			close(RPCOUTr);
			$| = 1;
			$ENV{'REQUEST_METHOD'} = 'GET';
			$ENV{'SCRIPT_NAME'} = '/fastrpc.cgi';
			$ENV{'SERVER_ROOT'} ||= $root_directory;
			my %acl;
			if ($base_remote_user ne 'root' &&
			    $base_remote_user ne 'admin') {
				# Need to fake up a login for the CGI!
				&read_acl(undef, \%acl, [ 'root' ]);
				$ENV{'BASE_REMOTE_USER'} =
					$ENV{'REMOTE_USER'} =
						$acl{'root'} ? 'root' : 'admin';
				}
			delete($ENV{'FOREIGN_MODULE_NAME'});
			delete($ENV{'FOREIGN_ROOT_DIRECTORY'});
			$ENV{'DISABLE_REFERERS_CHECK'} = 1;
			chdir($root_directory);
			if (!exec("$root_directory/fastrpc.cgi")) {
				print "exec failed : $!\n";
				exit 1;
				}
			}
		close(RPCOUTw);
		my $line;
		do {
			($line = <RPCOUTr>) =~ tr/\r\n//d;
			} while($line);
		$line = <RPCOUTr>;
		if ($line =~ /^0\s+(.*)/) {
			close(RPCOUTr);
			return &$main::remote_error_handler("RPC error : $2");
			}
		elsif ($line =~ /^1\s+(\S+)\s+(\S+)/) {
			# Started ok .. connect and save SID
			close(SOCK);
			close(RPCOUTr);
			my ($port, $sid, $error) = ($1, $2, undef);
			&open_socket("localhost", $port, $sid, \$error);
			return &$main::remote_error_handler("Failed to connect to fastrpc.cgi : $error") if ($error);
			$fast_fh_cache{$sn} = $sid;
			}
		else {
			# Unexpected response
			local $_;
			while(<RPCOUTr>) {
				$line .= $_;
				}
			close(RPCOUTr);
			return &$main::remote_error_handler(
				"Bad response from fastrpc.cgi : $line");
			}
		}
	# Got a connection .. send off the request
	my $fh = $fast_fh_cache{$sn};
	my $tostr = &serialise_variable($_[1]);
	print $fh length($tostr)," $fh\n";
	print $fh $tostr;
	my $rstr = <$fh>;
	if ($rstr eq '') {
		return &$main::remote_error_handler(
			"Error reading response length from fastrpc.cgi : $!")
		}
	my $rlen = int($rstr);
	my ($fromstr, $got);
	while(length($fromstr) < $rlen) {
		my $want = $rlen - length($fromstr);
		my $readrv = read($fh, $got, $want);
		if (!defined($readrv) && $! == EINTR) {
			# Interrupted read .. re-try
			next;
			}
		elsif ($readrv < 0 || !defined($readrv)) {
			return &$main::remote_error_handler(
				"Failed to read from fastrpc.cgi : $!")
			}
		elsif ($readrv == 0) {
			return &$main::remote_error_handler(
				"Read of $want bytes from fastrpc.cgi failed")
			}
		$fromstr .= $got;
		}
	my $from = &unserialise_variable($fromstr);
	if (!$from) {
		# No response at all
		return &$main::remote_error_handler("Remote Webmin error");
		}
	elsif (ref($from) ne 'HASH') {
		# Not a hash?!
		return &$main::remote_error_handler(
			"Invalid remote Webmin response : $from");
		}
	elsif (!$from->{'status'}) {
		# Call failed
		$from->{'rv'} =~ s/\s+at\s+(\S+)\s+line\s+(\d+)(,\s+<\S+>\s+line\s+(\d+))?//;
		return &$main::remote_error_handler($from->{'rv'});
		}
	if (defined($from->{'arv'})) {
		return @{$from->{'arv'}};
		}
	else {
		return $from->{'rv'};
		}
	}
else {
	# Call rpc.cgi on remote server
	my $tostr = &serialise_variable($_[1]);
	my $error = 0;
	my $con = &make_http_connection($ip, $serv->{'port'},
					$serv->{'ssl'}, "POST", "/rpc.cgi");
	return &$main::remote_error_handler("Failed to connect to $serv->{'host'} : $con") if (!ref($con));

	&write_http_connection($con, "Host: $serv->{'host'}\r\n");
	&write_http_connection($con, "User-agent: Webmin\r\n");
	my $auth = &encode_base64("$user:$pass");
	$auth =~ tr/\n//d;
	&write_http_connection($con, "Authorization: basic $auth\r\n");
	&write_http_connection($con, "Content-length: ",length($tostr),"\r\n");
	&write_http_connection($con, "\r\n");
	&write_http_connection($con, $tostr);

	# read back the response
	my $line = &read_http_connection($con);
	$line =~ tr/\r\n//d;
	if ($line =~ /^HTTP\/1\..\s+401\s+/) {
		return &$main::remote_error_handler("Login to RPC server as $user rejected");
		}
	$line =~ /^HTTP\/1\..\s+200\s+/ || return &$main::remote_error_handler("RPC HTTP error : $line");
	do {
		$line = &read_http_connection($con);
		$line =~ tr/\r\n//d;
		} while($line);
	my $fromstr;
	while($line = &read_http_connection($con)) {
		$fromstr .= $line;
		}
	close(SOCK);
	my $from = &unserialise_variable($fromstr);
	return &$main::remote_error_handler("Invalid RPC login to $serv->{'host'}") if (!$from->{'status'});
	if (defined($from->{'arv'})) {
		return @{$from->{'arv'}};
		}
	else {
		return $from->{'rv'};
		}
	}
}

=head2 remote_multi_callback(&servers, parallel, &function, arg|&args, &returns, &errors, [module, library])

Executes some function in parallel on multiple servers at once. Fills in
the returns and errors arrays respectively. If the module and library
parameters are given, that module is remotely required on the server first,
to check if it is connectable. The parameters are :

=item servers - A list of Webmin system hash references.

=item parallel - Number of parallel operations to perform.

=item function - Reference to function to call for each system.

=item args - Additional parameters to the function.

=item returns - Array ref to place return values into, in same order as servers.

=item errors - Array ref to place error messages into.

=item module - Optional module to require on the remote system first.

=item library - Optional library to require in the module.

=cut
sub remote_multi_callback
{
my ($servs, $parallel, $func, $args, $rets, $errs, $mod, $lib) = @_;
&remote_error_setup(\&remote_multi_callback_error);

# Call the functions
my $p = 0;
foreach my $g (@$servs) {
	my $rh = "READ$p";
	my $wh = "WRITE$p";
	pipe($rh, $wh);
	if (!fork()) {
		close($rh);
		$remote_multi_callback_err = undef;
		if ($mod) {
			# Require the remote lib
			&remote_foreign_require($g->{'host'}, $mod, $lib);
			if ($remote_multi_callback_err) {
				# Failed .. return error
				print $wh &serialise_variable(
					[ undef, $remote_multi_callback_err ]);
				exit(0);
				}
			}

		# Call the function
		my $a = ref($args) ? $args->[$p] : $args;
		my $rv = &$func($g, $a);

		# Return the result
		print $wh &serialise_variable(
			[ $rv, $remote_multi_callback_err ]);
		close($wh);
		exit(0);
		}
	close($wh);
	$p++;
	}

# Read back the results
$p = 0;
foreach my $g (@$servs) {
	my $rh = "READ$p";
	my $line = <$rh>;
	if (!$line) {
		$errs->[$p] = "Failed to read response from $g->{'host'}";
		}
	else {
		my $rv = &unserialise_variable($line);
		close($rh);
		$rets->[$p] = $rv->[0];
		$errs->[$p] = $rv->[1];
		}
	$p++;
	}

&remote_error_setup(undef);
}

sub remote_multi_callback_error
{
$remote_multi_callback_err = $_[0];
}

=head2 serialise_variable(variable)

Converts some variable (maybe a scalar, hash ref, array ref or scalar ref)
into a url-encoded string. In the cases of arrays and hashes, it is recursively
called on each member to serialize the entire object.

=cut
sub serialise_variable
{
if (!defined($_[0])) {
	return 'UNDEF';
	}
my $r = ref($_[0]);
my $rv;
if (!$r) {
	$rv = &urlize($_[0]);
	}
elsif ($r eq 'SCALAR') {
	$rv = &urlize(${$_[0]});
	}
elsif ($r eq 'ARRAY') {
	$rv = join(",", map { &urlize(&serialise_variable($_)) } @{$_[0]});
	}
elsif ($r eq 'HASH') {
	$rv = join(",", map { &urlize(&serialise_variable($_)).",".
			      &urlize(&serialise_variable($_[0]->{$_})) }
		            keys %{$_[0]});
	}
elsif ($r eq 'REF') {
	$rv = &serialise_variable(${$_[0]});
	}
elsif ($r eq 'CODE') {
	# Code not handled
	$rv = undef;
	}
elsif ($r) {
	# An object - treat as a hash
	$r = "OBJECT ".&urlize($r);
	$rv = join(",", map { &urlize(&serialise_variable($_)).",".
			      &urlize(&serialise_variable($_[0]->{$_})) }
		            keys %{$_[0]});
	}
return ($r ? $r : 'VAL').",".$rv;
}

=head2 unserialise_variable(string)

Converts a string created by serialise_variable() back into the original
scalar, hash ref, array ref or scalar ref. If the original variable was a Perl
object, the same class is used on this system, if available.

=cut
sub unserialise_variable
{
my @v = split(/,/, $_[0]);
my $rv;
if ($v[0] eq 'VAL') {
	@v = split(/,/, $_[0], -1);
	$rv = &un_urlize($v[1]);
	}
elsif ($v[0] eq 'SCALAR') {
	local $r = &un_urlize($v[1]);
	$rv = \$r;
	}
elsif ($v[0] eq 'ARRAY') {
	$rv = [ ];
	for(my $i=1; $i<@v; $i++) {
		push(@$rv, &unserialise_variable(&un_urlize($v[$i])));
		}
	}
elsif ($v[0] eq 'HASH') {
	$rv = { };
	for(my $i=1; $i<@v; $i+=2) {
		$rv->{&unserialise_variable(&un_urlize($v[$i]))} =
			&unserialise_variable(&un_urlize($v[$i+1]));
		}
	}
elsif ($v[0] eq 'REF') {
	local $r = &unserialise_variable($v[1]);
	$rv = \$r;
	}
elsif ($v[0] eq 'UNDEF') {
	$rv = undef;
	}
elsif ($v[0] =~ /^OBJECT\s+(.*)$/) {
	# An object hash that we have to re-bless
	my $cls = $1;
	$rv = { };
	for(my $i=1; $i<@v; $i+=2) {
		$rv->{&unserialise_variable(&un_urlize($v[$i]))} =
			&unserialise_variable(&un_urlize($v[$i+1]));
		}
	eval "use $cls";
	bless $rv, $cls;
	}
return $rv;
}

=head2 other_groups(user)

Returns a list of secondary groups a user is a member of, as a list of
group IDs.

=cut
sub other_groups
{
my ($user) = @_;
my @rv;
setgrent();
while(my @g = getgrent()) {
	my @m = split(/\s+/, $g[3]);
	push(@rv, $g[2]) if (&indexof($user, @m) >= 0);
	}
endgrent() if ($gconfig{'os_type'} ne 'hpux');
return @rv;
}

=head2 date_chooser_button(dayfield, monthfield, yearfield)

Returns HTML for a button that pops up a data chooser window. The parameters
are :

=item dayfield - Name of the text field to place the day of the month into.

=item monthfield - Name of the select field to select the month of the year in, indexed from 1.

=item yearfield - Name of the text field to place the year into.

=cut
sub date_chooser_button
{
return &theme_date_chooser_button(@_)
	if (defined(&theme_date_chooser_button));
my ($w, $h) = (250, 225);
if ($gconfig{'db_sizedate'}) {
	($w, $h) = split(/x/, $gconfig{'db_sizedate'});
	}
return "<input type=button onClick='window.dfield = form.$_[0]; window.mfield = form.$_[1]; window.yfield = form.$_[2]; window.open(\"$gconfig{'webprefix'}/date_chooser.cgi?day=\"+escape(dfield.value)+\"&month=\"+escape(mfield.selectedIndex)+\"&year=\"+yfield.value, \"chooser\", \"toolbar=no,menubar=no,scrollbars=yes,width=$w,height=$h\")' value=\"...\">\n";
}

=head2 help_file(module, file)

Returns the path to a module's help file of some name, typically under the
help directory with a .html extension.

=cut
sub help_file
{
my $mdir = &module_root_directory($_[0]);
my $dir = "$mdir/help";
foreach my $o (@lang_order_list) {
	my $lang = "$dir/$_[1].$o.html";
	return $lang if (-r $lang);
	}
return "$dir/$_[1].html";
}

=head2 seed_random

Seeds the random number generator, if not already done in this script. On Linux
this makes use of the current time, process ID and a read from /dev/urandom.
On other systems, only the current time and process ID are used.

=cut
sub seed_random
{
if (!$main::done_seed_random) {
	if (open(RANDOM, "/dev/urandom")) {
		my $buf;
		read(RANDOM, $buf, 4);
		close(RANDOM);
		srand(time() ^ $$ ^ $buf);
		}
	else {
		srand(time() ^ $$);
		}
	$main::done_seed_random = 1;
	}
}

=head2 disk_usage_kb(directory)

Returns the number of kB used by some directory and all subdirs. Implemented
by calling the C<du -k> command.

=cut
sub disk_usage_kb
{
my $dir = &translate_filename($_[0]);
my $out;
my $ex = &execute_command("du -sk ".quotemeta($dir), undef, \$out, undef, 0, 1);
if ($ex) {
	&execute_command("du -s ".quotemeta($dir), undef, \$out, undef, 0, 1);
	}
return $out =~ /^([0-9]+)/ ? $1 : "???";
}

=head2 recursive_disk_usage(directory, [skip-regexp], [only-regexp])

Returns the number of bytes taken up by all files in some directory and all
sub-directories, by summing up their lengths. The disk_usage_kb is more
reflective of reality, as the filesystem typically pads file sizes to 1k or
4k blocks.

=cut
sub recursive_disk_usage
{
my $dir = &translate_filename($_[0]);
my $skip = $_[1];
my $only = $_[2];
if (-l $dir) {
	return 0;
	}
elsif (!-d $dir) {
	my @st = stat($dir);
	return $st[7];
	}
else {
	my $rv = 0;
	opendir(DIR, $dir);
	my @files = readdir(DIR);
	closedir(DIR);
	foreach my $f (@files) {
		next if ($f eq "." || $f eq "..");
		next if ($skip && $f =~ /$skip/);
		next if ($only && $f !~ /$only/);
		$rv += &recursive_disk_usage("$dir/$f", $skip, $only);
		}
	return $rv;
	}
}

=head2 help_search_link(term, [ section, ... ] )

Returns HTML for a link to the man module for searching local and online
docs for various search terms. The term parameter can either be a single
word like 'bind', or a space-separated list of words. This function is typically
used by modules that want to refer users to additional documentation in man
pages or local system doc files.

=cut
sub help_search_link
{
if (&foreign_available("man") && !$tconfig{'nosearch'}) {
	my $for = &urlize(shift(@_));
	return "<a href='$gconfig{'webprefix'}/man/search.cgi?".
	       join("&", map { "section=$_" } @_)."&".
	       "for=$for&exact=1&check=".&get_module_name()."'>".
	       $text{'helpsearch'}."</a>\n";
	}
else {
	return "";
	}
}

=head2 make_http_connection(host, port, ssl, method, page, [&headers])

Opens a connection to some HTTP server, maybe through a proxy, and returns
a handle object. The handle can then be used to send additional headers
and read back a response. If anything goes wrong, returns an error string.
The parameters are :

=item host - Hostname or IP address of the webserver to connect to.

=item port - HTTP port number to connect to.

=item ssl - Set to 1 to connect in SSL mode.

=item method - HTTP method, like GET or POST.

=item page - Page to request on the webserver, like /foo/index.html

=item headers - Array ref of additional HTTP headers, each of which is a 2-element array ref.

=item bindip - IP address to bind to for outgoing HTTP connection

=item certreqs - A hash ref containing options for remote cert verification

=cut
sub make_http_connection
{
my ($host, $port, $ssl, $method, $page, $headers, $bindip, $certreqs) = @_;
my $htxt;
if ($headers) {
	foreach my $h (@$headers) {
		$htxt .= $h->[0].": ".$h->[1]."\r\n";
		}
	$htxt .= "\r\n";
	}
if (&is_readonly_mode()) {
	return "HTTP connections not allowed in readonly mode";
	}
my $rv = { 'fh' => time().$$ };
if ($ssl) {
	# Connect using SSL
	eval "use Net::SSLeay";
	$@ && return $text{'link_essl'};
	eval "Net::SSLeay::SSLeay_add_ssl_algorithms()";
	eval "Net::SSLeay::OpenSSL_add_all_algorithms()";
	eval "Net::SSLeay::load_error_strings()";
	$rv->{'ssl_ctx'} = Net::SSLeay::CTX_new() ||
		return "Failed to create SSL context";
	if ($certreqs && $certreqs->{'capath'}) {
		# Require that remote cert be signed by a valid CA
		$main::last_set_verify_err = undef;
		if (-d $certreqs->{'capath'}) {
			Net::SSLeay::CTX_load_verify_locations(
				$rv->{'ssl_ctx'}, "", $certreqs->{'capath'});
			}
		else {
			Net::SSLeay::CTX_load_verify_locations(
				$rv->{'ssl_ctx'}, $certreqs->{'capath'}, "");
			}
		Net::SSLeay::CTX_set_verify(
			$rv->{'ssl_ctx'}, &Net::SSLeay::VERIFY_PEER,
			sub
			{
			my $cert = Net::SSLeay::X509_STORE_CTX_get_current_cert($_[1]);
			if ($cert) {
				my $subject = Net::SSLeay::X509_NAME_oneline(
				    Net::SSLeay::X509_get_subject_name($cert));
				my $issuer = Net::SSLeay::X509_NAME_oneline(
				    Net::SSLeay::X509_get_issuer_name($cert));
				my $errnum = Net::SSLeay::X509_STORE_CTX_get_error($_[1]);
				if ($errnum) {
					$main::last_set_verify_err =
					  "Certificate is signed by an ".
					  "unknown CA : $issuer (code $errnum)";
					}
				else {
					$main::last_set_verify_err = undef;
					}
				}
			else {
				$main::last_set_verify_err =
				  "Could not fetch CA certificate from server";
				}
			return 1;
			});
		}
	$rv->{'ssl_con'} = Net::SSLeay::new($rv->{'ssl_ctx'}) ||
		return "Failed to create SSL connection";
	my $connected;
	if ($gconfig{'http_proxy'} =~ /^http:\/\/(\S+):(\d+)/ &&
	    !&no_proxy($host)) {
		# Via proxy
		my $error;
		&open_socket($1, $2, $rv->{'fh'}, \$error, $bindip);
		if (!$error) {
			# Connected OK
			my $fh = $rv->{'fh'};
			print $fh "CONNECT $host:$port HTTP/1.0\r\n";
			if ($gconfig{'proxy_user'}) {
				my $auth = &encode_base64(
				   "$gconfig{'proxy_user'}:".
				   "$gconfig{'proxy_pass'}");
				$auth =~ tr/\r\n//d;
				print $fh "Proxy-Authorization: Basic $auth\r\n";
				}
			print $fh "\r\n";
			my $line = <$fh>;
			if ($line =~ /^HTTP(\S+)\s+(\d+)\s+(.*)/) {
				return "Proxy error : $3" if ($2 != 200);
				}
			else {
				return "Proxy error : $line";
				}
			$line = <$fh>;
			$connected = 1;
			}
		elsif (!$gconfig{'proxy_fallback'}) {
			# Connection to proxy failed - give up
			return $error;
			}
		}
	if (!$connected) {
		# Direct connection
		my $error;
		&open_socket($host, $port, $rv->{'fh'}, \$error, $bindip);
		return $error if ($error);
		}
	Net::SSLeay::set_fd($rv->{'ssl_con'}, fileno($rv->{'fh'}));
	eval {
		my $snihost = $certreqs && $certreqs->{'host'};
		$snihost ||= $host;
		Net::SSLeay::set_tlsext_host_name($rv->{'ssl_con'}, $snihost);
		};
	Net::SSLeay::connect($rv->{'ssl_con'}) ||
		return "SSL connect() failed";
	if ($certreqs && !$certreqs->{'nocheckhost'}) {
		my $err = &validate_ssl_connection(
			$rv->{'ssl_con'},
			$certreqs->{'checkhost'} ||
			  $certreqs->{'host'} || $host,
			$certreqs);
		return "Invalid SSL certificate : $err" if ($err);
		}
	my $rtxt = "$method $page HTTP/1.0\r\n".$htxt;
	Net::SSLeay::write($rv->{'ssl_con'}, $rtxt);
	}
else {
	# Plain HTTP request
	my $connected;
	if ($gconfig{'http_proxy'} =~ /^http:\/\/(\S+):(\d+)/ &&
	    !&no_proxy($host)) {
		# Via a proxy
		my $error;
		&open_socket($1, $2, $rv->{'fh'}, \$error, $bindip);
		if (!$error) {
			# Connected OK
			$connected = 1;
			my $fh = $rv->{'fh'};
			my $rtxt = $method." ".
				   "http://$host:$port$page HTTP/1.0\r\n";
			if ($gconfig{'proxy_user'}) {
				my $auth = &encode_base64(
				   "$gconfig{'proxy_user'}:".
				   "$gconfig{'proxy_pass'}");
				$auth =~ tr/\r\n//d;
				$rtxt .= "Proxy-Authorization: Basic $auth\r\n";
				}
			$rtxt .= $htxt;
			print $fh $rtxt;
			}
		elsif (!$gconfig{'proxy_fallback'}) {
			return $error;
			}
		}
	if (!$connected) {
		# Connecting directly
		my $error;
		&open_socket($host, $port, $rv->{'fh'}, \$error, $bindip);
		return $error if ($error);
		my $fh = $rv->{'fh'};
		my $rtxt = "$method $page HTTP/1.0\r\n".$htxt;
		print $fh $rtxt;
		}
	}
return $rv;
}

=head2 validate_ssl_connection(&ssl-handle, hostname, &requirements)

Validates the SSL certificate presented by a remote server, and returns an
error message if any requirements were not met.

=cut
sub validate_ssl_connection
{
my ($ssl, $host, $reqs) = @_;
$host = lc($host);
my $x509 = Net::SSLeay::get_peer_certificate($ssl);
$x509 || return "Could not fetch peer certificate";
if ($reqs->{'host'} || $reqs->{'checkhost'}) {
	# Check for sensible hostname
	my @subjects;
	my $subject = Net::SSLeay::X509_NAME_oneline(
		Net::SSLeay::X509_get_subject_name($x509));
	$subject =~ /CN=([a-z0-9\-\_\.\*]+)/i ||
		return "No CN found in subject $subject";
	push(@subjects, lc($1));
	my @altlist = Net::SSLeay::X509_get_subjectAltNames($x509);
	for(my $i=1; $i<@altlist; $i+=2) {
		push(@subjects, lc($altlist[$i]));
		}
	my @errs;
	foreach my $cn (@subjects) {
		if ($cn =~ /^\*\.(.*)$/) {
			# For a sub-domain
			my $subcn = $1;
			$host eq $subcn || $host =~ /\.\Q$subcn\E$/ ||
			    push(@errs, "Certificate is for $cn, not $host.");
			}
		elsif ($cn eq "*") {
			# Matches anything .. but this may fail the
			# self-signed check
			}
		else {
			# For an exact domain
			$host eq $cn ||
			    push(@errs, "Certificate is for $cn, not $host.");
			}
		}
	if (scalar(@errs) == scalar(@subjects)) {
		# All subjects were bad
		return join(" ", @errs);
		}
	}
if ($reqs->{'self'}) {
	# Check if self-signed
	my $subject = Net::SSLeay::X509_NAME_oneline(
		Net::SSLeay::X509_get_subject_name($x509));
	my $issuer = Net::SSLeay::X509_NAME_oneline(
		Net::SSLeay::X509_get_issuer_name($x509));
	if ($subject eq $issuer) {
		return "Certificate is self-signed by $subject";
		}
	}
if ($reqs->{'capath'}) {
	# Check if CA is signed by a valid authority (set in a callback)
	return $main::last_set_verify_err if ($main::last_set_verify_err);
	}
return undef;
}

=head2 read_http_connection(&handle, [bytes])

Reads either one line or up to the specified number of bytes from the handle,
originally supplied by make_http_connection.

=cut
sub read_http_connection
{
my ($h, $want) = @_;
my $rv;
if ($h->{'ssl_con'}) {
	if (!$want) {
		my ($idx, $more);
		while(($idx = index($h->{'buffer'}, "\n")) < 0) {
			# need to read more..
			if (!($more = Net::SSLeay::read($h->{'ssl_con'}))) {
				# end of the data
				$rv = $h->{'buffer'};
				delete($h->{'buffer'});
				return $rv;
				}
			$h->{'buffer'} .= $more;
			}
		$rv = substr($h->{'buffer'}, 0, $idx+1);
		$h->{'buffer'} = substr($h->{'buffer'}, $idx+1);
		}
	else {
		if (length($h->{'buffer'})) {
			$rv = $h->{'buffer'};
			delete($h->{'buffer'});
			}
		else {
			$rv = Net::SSLeay::read($h->{'ssl_con'}, $want);
			}
		}
	}
else {
	if ($want) {
		read($h->{'fh'}, $rv, $want) > 0 || return undef;
		}
	else {
		my $fh = $h->{'fh'};
		$rv = <$fh>;
		}
	}
$rv = undef if ($rv eq "");
return $rv;
}

=head2 write_http_connection(&handle, [data+])

Writes the given data to the given HTTP connection handle.

=cut
sub write_http_connection
{
my $h = shift(@_);
my $fh = $h->{'fh'};
my $allok = 1;
if ($h->{'ssl_ctx'}) {
	foreach my $s (@_) {
		my $ok = Net::SSLeay::write($h->{'ssl_con'}, $s);
		$allok = 0 if (!$ok);
		}
	}
else {
	my $ok = (print $fh @_);
	$allok = 0 if (!$ok);
	}
return $allok;
}

=head2 close_http_connection(&handle)

Closes a connection to an HTTP server, identified by the given handle.

=cut
sub close_http_connection
{
my ($h) = @_;
return close($h->{'fh'});
}

=head2 clean_environment

Deletes any environment variables inherited from miniserv so that they
won't be passed to programs started by webmin. This is useful when calling
programs that check for CGI-related environment variables and modify their
behaviour, and to avoid passing sensitive variables to un-trusted programs.

=cut
sub clean_environment
{
%UNCLEAN_ENV = %ENV;
foreach my $k (keys %ENV) {
	if ($k =~ /^(HTTP|VIRTUALSERVER|QUOTA|USERADMIN)_/) {
		delete($ENV{$k});
		}
	}
foreach my $e ('WEBMIN_CONFIG', 'SERVER_NAME', 'CONTENT_TYPE', 'REQUEST_URI',
	    'PATH_INFO', 'WEBMIN_VAR', 'REQUEST_METHOD', 'GATEWAY_INTERFACE',
	    'QUERY_STRING', 'REMOTE_USER', 'SERVER_SOFTWARE', 'SERVER_PROTOCOL',
	    'REMOTE_HOST', 'SERVER_PORT', 'DOCUMENT_ROOT', 'SERVER_ROOT',
	    'MINISERV_CONFIG', 'SCRIPT_NAME', 'SERVER_ADMIN', 'CONTENT_LENGTH',
	    'HTTPS', 'FOREIGN_MODULE_NAME', 'FOREIGN_ROOT_DIRECTORY',
	    'SCRIPT_FILENAME', 'PATH_TRANSLATED', 'BASE_REMOTE_USER',
	    'DOCUMENT_REALROOT', 'MINISERV_CONFIG', 'MYSQL_PWD',
	    'MINISERV_PID') {
	delete($ENV{$e});
	}
}

=head2 reset_environment

Puts the environment back how it was before clean_environment was callled.

=cut
sub reset_environment
{
if (%UNCLEAN_ENV) {
	foreach my $k (keys %UNCLEAN_ENV) {
		$ENV{$k} = $UNCLEAN_ENV{$k};
		}
	undef(%UNCLEAN_ENV);
	}
}

=head2 clean_language

Sets all language and locale-related environment variables to US english, to
ensure that commands run output in the expected language. Can be reverted by
reset_environment.

=cut
sub clean_language
{
if (!%UNCLEAN_ENV) {
	%UNCLEAN_ENV = %ENV;
	}
$ENV{'LANG'} = '';
$ENV{'LANGUAGE'} = '';
$ENV{'LC_ALL'} = '';
$ENV{'LOCALE'} = '';
}

=head2 progress_callback

Never called directly, but useful for passing to &http_download to print
out progress of an HTTP request.

=cut
sub progress_callback
{
if (defined(&theme_progress_callback)) {
	# Call the theme override
	return &theme_progress_callback(@_);
	}
if ($_[0] == 2) {
	# Got size
	print $progress_callback_prefix;
	if ($_[1]) {
		$progress_size = $_[1];
		$progress_step = int($_[1] / 10);
		print &text('progress_size2', $progress_callback_url,
			    &nice_size($progress_size)),"<br>\n";
		}
	else {
		$progress_size = undef;
		print &text('progress_nosize', $progress_callback_url),"<br>\n";
		}
	$last_progress_time = $last_progress_size = undef;
	}
elsif ($_[0] == 3) {
	# Got data update
	my $sp = $progress_callback_prefix.("&nbsp;" x 5);
	if ($progress_size) {
		# And we have a size to compare against
		my $st = int(($_[1] * 10) / $progress_size);
		my $time_now = time();
		if ($st != $progress_step ||
		    $time_now - $last_progress_time > 60) {
			# Show progress every 10% or 60 seconds
			print $sp,&text('progress_datan', &nice_size($_[1]),
				        int($_[1]*100/$progress_size)),"<br>\n";
			$last_progress_time = $time_now;
			}
		$progress_step = $st;
		}
	else {
		# No total size .. so only show in 1M jumps
		if ($_[1] > $last_progress_size+1024*1024) {
			print $sp,&text('progress_data2n',
					&nice_size($_[1])),"<br>\n";
			$last_progress_size = $_[1];
			}
		}
	}
elsif ($_[0] == 4) {
	# All done downloading
	print $progress_callback_prefix,&text('progress_done'),"<br>\n";
	}
elsif ($_[0] == 5) {
	# Got new location after redirect
	$progress_callback_url = $_[1];
	}
elsif ($_[0] == 6) {
	# URL is in cache
	$progress_callback_url = $_[1];
	print &text('progress_incache', $progress_callback_url),"<br>\n";
	}
}

=head2 switch_to_remote_user

Changes the user and group of the current process to that of the unix user
with the same name as the current webmin login, or fails if there is none.
This should be called by Usermin module scripts that only need to run with
limited permissions.

=cut
sub switch_to_remote_user
{
@remote_user_info = $remote_user ? getpwnam($remote_user) :
		    		   getpwuid($<);
@remote_user_info || &error(&text('switch_remote_euser', $remote_user));
&create_missing_homedir(\@remote_user_info);
if ($< == 0) {
	&switch_to_unix_user(\@remote_user_info);
	$ENV{'USER'} = $ENV{'LOGNAME'} = $remote_user;
	$ENV{'HOME'} = $remote_user_info[7];
	}
# Export global variables to caller
if ($main::export_to_caller) {
	my ($callpkg) = caller();
	eval "\@${callpkg}::remote_user_info = \@remote_user_info";
	}
}

=head2 switch_to_unix_user(&user-details)

Switches the current process to the UID and group ID from the given list
of user details, which must be in the format returned by getpwnam.

=cut
sub switch_to_unix_user
{
my ($uinfo) = @_;
if (!defined($uinfo->[0])) {
	# No username given, so just use given GID
	($(, $)) = ( $uinfo->[3], "$uinfo->[3] $uinfo->[3]" );
	}
else {
	# Use all groups from user
	($(, $)) = ( $uinfo->[3],
		     "$uinfo->[3] ".join(" ", $uinfo->[3],
					 &other_groups($uinfo->[0])) );
	}
eval {
	POSIX::setuid($uinfo->[2]);
	};
if ($< != $uinfo->[2] || $> != $uinfo->[2]) {
	($>, $<) = ( $uinfo->[2], $uinfo->[2] );
	}
}

=head2 eval_as_unix_user(username, &code)

Runs some code fragment with the effective UID and GID switch to that
of the given Unix user, so that file IO takes place with his permissions.

=cut

sub eval_as_unix_user
{
my ($user, $code) = @_;
my @uinfo = getpwnam($user);
if (!scalar(@uinfo)) {
	&error("eval_as_unix_user called with invalid user $user");
	}
$) = $uinfo[3]." ".join(" ", $uinfo[3], &other_groups($user));
$> = $uinfo[2];
my @rv;
eval {
	local $main::error_must_die = 1;
	@rv = &$code();
	};
my $err = $@;
$) = 0;
$> = 0;
if ($err) {
	$err =~ s/\s+at\s+(\/\S+)\s+line\s+(\d+)\.?//;
	&error($err);
	}
return wantarray ? @rv : $rv[0];
}

=head2 create_user_config_dirs

Creates per-user config directories and sets $user_config_directory and
$user_module_config_directory to them. Also reads per-user module configs
into %userconfig. This should be called by Usermin module scripts that need
to store per-user preferences or other settings.

=cut
sub create_user_config_dirs
{
return if (!$gconfig{'userconfig'});
my @uinfo = @remote_user_info ? @remote_user_info : getpwnam($remote_user);
return if (!@uinfo || !$uinfo[7]);
&create_missing_homedir(\@uinfo);
$user_config_directory = "$uinfo[7]/$gconfig{'userconfig'}";
if (!-d $user_config_directory) {
	mkdir($user_config_directory, 0700) ||
		&error("Failed to create $user_config_directory : $!");
	if ($< == 0 && $uinfo[2]) {
		chown($uinfo[2], $uinfo[3], $user_config_directory);
		}
	}
if (&get_module_name()) {
	$user_module_config_directory = $user_config_directory."/".
					&get_module_name();
	if (!-d $user_module_config_directory) {
		mkdir($user_module_config_directory, 0700) ||
			&error("Failed to create $user_module_config_directory : $!");
		if ($< == 0 && $uinfo[2]) {
			chown($uinfo[2], $uinfo[3], $user_config_directory);
			}
		}
	undef(%userconfig);
	&read_file_cached("$module_root_directory/defaultuconfig",
			  \%userconfig);
	&read_file_cached("$module_config_directory/uconfig", \%userconfig);
	&read_file_cached("$user_module_config_directory/config",
			  \%userconfig);
	}

# Export global variables to caller
if ($main::export_to_caller) {
	my ($callpkg) = caller();
	foreach my $v ('$user_config_directory',
		       '$user_module_config_directory', '%userconfig') {
		my ($vt, $vn) = split('', $v, 2);
		eval "${vt}${callpkg}::${vn} = ${vt}${vn}";
		}
	}
}

=head2 create_missing_homedir(&uinfo)

If auto homedir creation is enabled, create one for this user if needed.
For internal use only.

=cut
sub create_missing_homedir
{
my ($uinfo) = @_;
if (!-e $uinfo->[7] && $gconfig{'create_homedir'}) {
	# Use has no home dir .. make one
	system("mkdir -p ".quotemeta($uinfo->[7]));
	chown($uinfo->[2], $uinfo->[3], $uinfo->[7]);
	if ($gconfig{'create_homedir_perms'} ne '') {
		chmod(oct($gconfig{'create_homedir_perms'}), $uinfo->[7]);
		}
	}
}

=head2 filter_javascript(text)

Disables all javascript <script>, onClick= and so on tags in the given HTML,
and returns the new HTML. Useful for displaying HTML from an un-trusted source.

=cut
sub filter_javascript
{
my ($rv) = @_;
$rv =~ s/<\s*script[^>]*>([\000-\377]*?)<\s*\/script\s*>//gi;
$rv =~ s/(on(Abort|BeforeUnload|Blur|Change|Click|ContextMenu|Copy|Cut|DblClick|Drag|DragEnd|DragEnter|DragLeave|DragOver|DragStart|DragDrop|Drop|Error|Focus|FocusIn|FocusOut|HashChange|Input|Invalid|KeyDown|KeyPress|KeyUp|Load|MouseDown|MouseEnter|MouseLeave|MouseMove|MouseOut|MouseOver|MouseUp|Move|Paste|PageShow|PageHide|Reset|Resize|Scroll|Search|Select|Submit|Toggle|Unload)=)/x$1/gi;
$rv =~ s/(javascript:)/x$1/gi;
$rv =~ s/(vbscript:)/x$1/gi;
$rv =~ s/<([^>]*\s|)(on\S+=)(.*)>/<$1x$2$3>/gi;
return $rv;
}

=head2 resolve_links(path)

Given a path that may contain symbolic links, returns the real path.

=cut
sub resolve_links
{
my ($path) = @_;
$path =~ s/\/+/\//g;
$path =~ s/\/$// if ($path ne "/");
my @p = split(/\/+/, $path);
shift(@p);
for(my $i=0; $i<@p; $i++) {
	my $sofar = "/".join("/", @p[0..$i]);
	my $lnk = readlink($sofar);
	if ($lnk eq $sofar) {
		# Link to itself! Cannot do anything more really ..
		last;
		}
	elsif ($lnk =~ /^\//) {
		# Link is absolute..
		return &resolve_links($lnk."/".join("/", @p[$i+1 .. $#p]));
		}
	elsif ($lnk) {
		# Link is relative
		return &resolve_links("/".join("/", @p[0..$i-1])."/".$lnk."/".join("/", @p[$i+1 .. $#p]));
		}
	}
return $path;
}

=head2 simplify_path(path, bogus)

Given a path, maybe containing elements ".." and "." , convert it to a
clean, absolute form. Returns undef if this is not possible.

=cut
sub simplify_path
{
my ($dir) = @_;
$dir =~ s/^\/+//g;
$dir =~ s/\/+$//g;
my @bits = split(/\/+/, $dir);
my @fixedbits = ();
$_[1] = 0;
foreach my $b (@bits) {
        if ($b eq ".") {
                # Do nothing..
                }
        elsif ($b eq "..") {
                # Remove last dir
                if (scalar(@fixedbits) == 0) {
			# Cannot! Already at root!
			return undef;
                        }
                pop(@fixedbits);
                }
        else {
                # Add dir to list
                push(@fixedbits, $b);
                }
        }
return "/".join('/', @fixedbits);
}

=head2 same_file(file1, file2)

Returns 1 if two files are actually the same

=cut
sub same_file
{
return 1 if ($_[0] eq $_[1]);
return 0 if ($_[0] !~ /^\// || $_[1] !~ /^\//);
my @stat1 = $stat_cache{$_[0]} ? @{$stat_cache{$_[0]}}
			       : (@{$stat_cache{$_[0]}} = stat($_[0]));
my @stat2 = $stat_cache{$_[1]} ? @{$stat_cache{$_[1]}}
			       : (@{$stat_cache{$_[1]}} = stat($_[1]));
return 0 if (!@stat1 || !@stat2);
return $stat1[0] == $stat2[0] && $stat1[1] == $stat2[1];
}

=head2 flush_webmin_caches

Clears all in-memory and on-disk caches used by Webmin.

=cut
sub flush_webmin_caches
{
undef(%main::read_file_cache);
undef(%main::acl_hash_cache);
undef(%main::acl_array_cache);
undef(%main::has_command_cache);
undef(@main::list_languages_cache);
undef($main::got_list_usermods_cache);
undef(@main::list_usermods_cache);
undef(%main::foreign_installed_cache);
unlink("$config_directory/module.infos.cache");
unlink("$var_directory/module.infos.cache");
&get_all_module_infos();
}

=head2 list_usermods

Returns a list of additional module restrictions. For internal use in
Usermin only.

=cut
sub list_usermods
{
if (!$main::got_list_usermods_cache) {
	@main::list_usermods_cache = ( );
	local $_;
	open(USERMODS, "$config_directory/usermin.mods");
	while(<USERMODS>) {
		if (/^([^:]+):(\+|-|):(.*)/) {
			push(@main::list_usermods_cache,
			     [ $1, $2, [ split(/\s+/, $3) ] ]);
			}
		}
	close(USERMODS);
	$main::got_list_usermods_cache = 1;
	}
return @main::list_usermods_cache;
}

=head2 available_usermods(&allmods, &usermods)

Returns a list of modules that are available to the given user, based
on usermod additional/subtractions. For internal use by Usermin only.

=cut
sub available_usermods
{
return @{$_[0]} if (!@{$_[1]});

my %mods = map { $_->{'dir'}, 1 } @{$_[0]};
my @uinfo = @remote_user_info;
@uinfo = getpwnam($remote_user) if (!@uinfo);
foreach my $u (@{$_[1]}) {
	my $applies;
	if ($u->[0] eq "*" || $u->[0] eq $remote_user) {
		$applies++;
		}
	elsif ($u->[0] =~ /^\@(.*)$/) {
		# Check for group membership
		my @ginfo = getgrnam($1);
		$applies++ if (@ginfo && ($ginfo[2] == $uinfo[3] ||
			&indexof($remote_user, split(/\s+/, $ginfo[3])) >= 0));
		}
	elsif ($u->[0] =~ /^\//) {
		# Check users and groups in file
		local $_;
		open(USERFILE, $u->[0]);
		while(<USERFILE>) {
			tr/\r\n//d;
			if ($_ eq $remote_user) {
				$applies++;
				}
			elsif (/^\@(.*)$/) {
				my @ginfo = getgrnam($1);
				$applies++
				  if (@ginfo && ($ginfo[2] == $uinfo[3] ||
				      &indexof($remote_user,
					       split(/\s+/, $ginfo[3])) >= 0));
				}
			last if ($applies);
			}
		close(USERFILE);
		}
	if ($applies) {
		if ($u->[1] eq "+") {
			map { $mods{$_}++ } @{$u->[2]};
			}
		elsif ($u->[1] eq "-") {
			map { delete($mods{$_}) } @{$u->[2]};
			}
		else {
			undef(%mods);
			map { $mods{$_}++ } @{$u->[2]};
			}
		}
	}
return grep { $mods{$_->{'dir'}} } @{$_[0]};
}

=head2 get_available_module_infos(nocache)

Returns a list of modules available to the current user, based on
operating system support, access control and usermod restrictions. Useful
in themes that need to display a list of modules the user can use.
Each element of the returned array is a hash reference in the same format as
returned by get_module_info.

=cut
sub get_available_module_infos
{
my (%acl, %uacl);
&read_acl(\%acl, \%uacl, [ $base_remote_user ]);
my $risk = $gconfig{'risk_'.$base_remote_user};
my @rv;
foreach my $minfo (&get_all_module_infos($_[0])) {
	next if (!&check_os_support($minfo));
	if ($risk) {
		# Check module risk level
		next if ($risk ne 'high' && $minfo->{'risk'} &&
			 $minfo->{'risk'} !~ /$risk/);
		}
	else {
		# Check user's ACL
		next if (!$acl{$base_remote_user,$minfo->{'dir'}} &&
			 !$acl{$base_remote_user,"*"});
		}
	next if (&is_readonly_mode() && !$minfo->{'readonly'});
	push(@rv, $minfo);
	}

# Check usermod restrictions
my @usermods = &list_usermods();
@rv = sort { lc($a->{'desc'}) cmp lc($b->{'desc'}) }
	    &available_usermods(\@rv, \@usermods);

# Check RBAC restrictions
my @rbacrv;
foreach my $m (@rv) {
	if (&supports_rbac($m->{'dir'}) &&
	    &use_rbac_module_acl(undef, $m->{'dir'})) {
		local $rbacs = &get_rbac_module_acl($remote_user,
						    $m->{'dir'});
		if ($rbacs) {
			# RBAC allows
			push(@rbacrv, $m);
			}
		}
	else {
		# Module or system doesn't support RBAC
		push(@rbacrv, $m) if (!$gconfig{'rbacdeny_'.$base_remote_user});
		}
	}

# Check theme vetos
my @themerv;
if (defined(&theme_foreign_available)) {
	foreach my $m (@rbacrv) {
		if (&theme_foreign_available($m->{'dir'})) {
			push(@themerv, $m);
			}
		}
	}
else {
	@themerv = @rbacrv;
	}

# Check licence module vetos
my @licrv;
if ($main::licence_module) {
	foreach my $m (@themerv) {
		if (&foreign_call($main::licence_module,
				  "check_module_licence", $m->{'dir'})) {
			push(@licrv, $m);
			}
		}
	}
else {
	@licrv = @themerv;
	}

return @licrv;
}

=head2 get_visible_module_infos(nocache)

Like get_available_module_infos, but excludes hidden modules from the list.
Each element of the returned array is a hash reference in the same format as
returned by get_module_info.

=cut
sub get_visible_module_infos
{
my ($nocache) = @_;
my $pn = &get_product_name();
return grep { !$_->{'hidden'} &&
	      !$_->{$pn.'_hidden'} } &get_available_module_infos($nocache);
}

=head2 get_visible_modules_categories(nocache)

Returns a list of Webmin module categories, each of which is a hash ref
with 'code', 'desc' and 'modules' keys. The modules value is an array ref
of modules in the category, in the format returned by get_module_info.
Un-used modules are automatically assigned to the 'unused' category, and
those with no category are put into 'others'.

=cut
sub get_visible_modules_categories
{
my ($nocache) = @_;
my @mods = &get_visible_module_infos($nocache);
my @unmods;
if (&get_product_name() eq 'webmin') {
	@unmods = grep { $_->{'installed'} eq '0' } @mods;
	@mods = grep { $_->{'installed'} ne '0' } @mods;
	}
my %cats = &list_categories(\@mods);
my @rv;
foreach my $c (keys %cats) {
	my $cat = { 'code' => $c || 'other',
		    'desc' => $cats{$c} };
	$cat->{'modules'} = [ grep { $_->{'category'} eq $c } @mods ];
	push(@rv, $cat);
	}
@rv = sort { ($b->{'code'} eq "others" ? "" : $b->{'code'}) cmp
	     ($a->{'code'} eq "others" ? "" : $a->{'code'}) } @rv;
if (@unmods) {
	# Add un-installed modules in magic category
	my $cat = { 'code' => 'unused',
		    'desc' => $text{'main_unused'},
		    'unused' => 1,
		    'modules' => \@unmods };
	push(@rv, $cat);
	}
return @rv;
}

=head2 is_under_directory(directory, file)

Returns 1 if the given file is under the specified directory, 0 if not.
Symlinks are taken into account in the file to find it's 'real' location.

=cut
sub is_under_directory
{
my ($dir, $file) = @_;
return 1 if ($dir eq "/");
return 0 if ($file =~ /\.\./);
my $ld = &resolve_links($dir);
if ($ld ne $dir) {
	return &is_under_directory($ld, $file);
	}
my $lp = &resolve_links($file);
if ($lp ne $file) {
	return &is_under_directory($dir, $lp);
	}
return 0 if (length($file) < length($dir));
return 1 if ($dir eq $file);
$dir =~ s/\/*$/\//;
return substr($file, 0, length($dir)) eq $dir;
}

=head2 parse_http_url(url, [basehost, baseport, basepage, basessl])

Given an absolute URL, returns the host, port, page and ssl flag components.
If a username and password are given before the hostname, return those too.
Relative URLs can also be parsed, if the base information is provided.
SSL mode 0 = HTTP, 1 = HTTPS, 2 = FTP.

=cut
sub parse_http_url
{
if ($_[0] =~ /^(http|https|ftp):\/\/([^\@]+\@)?\[([^\]]+)\](:(\d+))?(\/\S*)?$/ ||
    $_[0] =~ /^(http|https|ftp):\/\/([^\@]+\@)?([^:\/]+)(:(\d+))?(\/\S*)?$/) {
	# An absolute URL
	my $ssl = $1 eq 'https' ? 1 : $1 eq 'ftp' ? 2 : 0;
	my @rv = ($3,
		  $4 ? $5 : $ssl == 1 ? 443 : $ssl == 2 ? 21 : 80,
		  $6 || "/",
		  $ssl,
		 );
	if ($2 =~ /^([^:]+):(\S+)\@/) {
		push(@rv, $1, $2);
		}
	return @rv;
	}
elsif (!$_[1]) {
	# Could not parse
	return undef;
	}
elsif ($_[0] =~ /^\/\S*$/) {
	# A relative to the server URL
	return ($_[1], $_[2], $_[0], $_[4], $_[5], $_[6]);
	}
else {
	# A relative to the directory URL
	my $page = $_[3];
	$page =~ s/[^\/]+$//;
	return ($_[1], $_[2], $page.$_[0], $_[4], $_[5], $_[6]);
	}
}

=head2 check_clicks_function

Returns HTML for a JavaScript function called check_clicks that returns
true when first called, but false subsequently. Useful on onClick for
critical buttons. Deprecated, as this method of preventing duplicate actions
is un-reliable.

=cut
sub check_clicks_function
{
return <<EOF;
<script type='text/javascript'>
clicks = 0;
function check_clicks(form)
{
clicks++;
if (clicks == 1)
	return true;
else {
	if (form != null) {
		for(i=0; i<form.length; i++)
			form.elements[i].disabled = true;
		}
	return false;
	}
}
</script>
EOF
}

=head2 load_entities_map

Returns a hash ref containing mappings between HTML entities (like ouml) and
ascii values (like 246). Mainly for internal use.

=cut
sub load_entities_map
{
if (!%entities_map_cache) {
	local $_;
	open(EMAP, "$root_directory/entities_map.txt");
	while(<EMAP>) {
		if (/^(\d+)\s+(\S+)/) {
			$entities_map_cache{$2} = $1;
			}
		}
	close(EMAP);
	}
return \%entities_map_cache;
}

=head2 entities_to_ascii(string)

Given a string containing HTML entities like &ouml; and &#55;, replace them
with their ASCII equivalents.

=cut
sub entities_to_ascii
{
my ($str) = @_;
my $emap = &load_entities_map();
$str =~ s/&([a-z]+);/chr($emap->{$1})/ge;
$str =~ s/&#(\d+);/chr($1)/ge;
return $str;
}

=head2 get_product_name

Returns either 'webmin' or 'usermin', depending on which program the current
module is in. Useful for modules that can be installed into either.

=cut
sub get_product_name
{
return $gconfig{'product'} if (defined($gconfig{'product'}));
return defined($gconfig{'userconfig'}) ? 'usermin' : 'webmin';
}

=head2 get_charset

Returns the character set for the current language, such as iso-8859-1.

=cut
sub get_charset
{
my $charset = defined($gconfig{'charset'}) ? $gconfig{'charset'} :
		 $current_lang_info->{'charset'} ?
		 $current_lang_info->{'charset'} : $default_charset;
return $charset;
}

=head2 get_display_hostname

Returns the system's hostname for UI display purposes. This may be different
from the actual hostname if you administrator has configured it so in the
Webmin Configuration module.

=cut
sub get_display_hostname
{
if ($gconfig{'hostnamemode'} == 0) {
	return &get_system_hostname();
	}
elsif ($gconfig{'hostnamemode'} == 3) {
	return $gconfig{'hostnamedisplay'};
	}
else {
	my $h = $ENV{'HTTP_HOST'};
	return &get_system_hostname() if (!$h);
	$h =~ s/:\d+//g;
	if ($gconfig{'hostnamemode'} == 2) {
		$h =~ s/^(www|ftp|mail)\.//i;
		}
	return $h;
	}
}

=head2 save_module_config([&config], [modulename])

Saves the configuration for some module. The config parameter is an optional
hash reference of names and values to save, which defaults to the global
%config hash. The modulename parameter is the module to update the config
file, which defaults to the current module.

=cut
sub save_module_config
{
my $c = $_[0] || { &get_module_variable('%config') };
my $m;
if (defined($_[1])) {
	$m = $_[1];
	}
else {
	$m = &get_module_name();
	$m || &error("could not compute current module in save_module_config");
	}
&write_file("$config_directory/$m/config", $c);
}

=head2 save_user_module_config([&config], [modulename])

Saves the user's Usermin preferences for some module. The config parameter is
an optional hash reference of names and values to save, which defaults to the
global %userconfig hash. The modulename parameter is the module to update the
config file, which defaults to the current module.

=cut
sub save_user_module_config
{
my $c = $_[0] || { &get_module_variable('%userconfig') };
my $m = $_[1] || &get_module_name();
my $ucd = $user_config_directory;
if (!$ucd) {
	my @uinfo = @remote_user_info ? @remote_user_info
				      : getpwnam($remote_user);
	return if (!@uinfo || !$uinfo[7]);
	$ucd = "$uinfo[7]/$gconfig{'userconfig'}";
	}
&write_file("$ucd/$m/config", $c);
}

=head2 nice_size(bytes, [min])

Converts a number of bytes into a number followed by a suffix like GB, MB
or kB. Rounding is to two decimal digits. The optional min parameter sets the
smallest units to use - so you could pass 1024*1024 to never show bytes or kB.

=cut
sub nice_size
{
my ($units, $uname);
&load_theme_library();
if (defined(&theme_nice_size) &&
    $main::header_content_type eq "text/html" &&
    $main::webmin_script_type eq "web") {
	return &theme_nice_size(@_);
	}
if (abs($_[0]) > 1024*1024*1024*1024 || $_[1] >= 1024*1024*1024*1024) {
	$units = 1024*1024*1024*1024;
	$uname = "TB";
	}
elsif (abs($_[0]) > 1024*1024*1024 || $_[1] >= 1024*1024*1024) {
	$units = 1024*1024*1024;
	$uname = "GB";
	}
elsif (abs($_[0]) > 1024*1024 || $_[1] >= 1024*1024) {
	$units = 1024*1024;
	$uname = "MB";
	}
elsif (abs($_[0]) > 1024 || $_[1] >= 1024) {
	$units = 1024;
	$uname = "kB";
	}
else {
	$units = 1;
	$uname = "bytes";
	}
my $sz = sprintf("%.2f", ($_[0]*1.0 / $units));
$sz =~ s/\.00$//;
return $sz." ".$uname;
}

=head2 get_perl_path

Returns the path to Perl currently in use, such as /usr/bin/perl.

=cut
sub get_perl_path
{
if (open(PERL, "$config_directory/perl-path")) {
	my $rv;
	chop($rv = <PERL>);
	close(PERL);
	return $rv;
	}
return $^X if (-x $^X);
return &has_command("perl");
}

=head2 get_goto_module([&mods])

Returns the details of a module that the current user should be re-directed
to after logging in, or undef if none. Useful for themes.

=cut
sub get_goto_module
{
my @mods = $_[0] ? @{$_[0]} : &get_visible_module_infos();
if ($gconfig{'gotomodule'}) {
	my ($goto) = grep { $_->{'dir'} eq $gconfig{'gotomodule'} } @mods;
	return $goto if ($goto);
	}
if (@mods == 1 && $gconfig{'gotoone'}) {
	return $mods[0];
	}
return undef;
}

=head2 select_all_link(field, form, [text])

Returns HTML for a 'Select all' link that uses Javascript to select
multiple checkboxes with the same name. The parameters are :

=item field - Name of the checkbox inputs.

=item form - Index of the form on the page.

=item text - Message for the link, defaulting to 'Select all'.

=cut
sub select_all_link
{
return &theme_select_all_link(@_) if (defined(&theme_select_all_link));
my ($field, $form, $text) = @_;
$form = int($form);
$text ||= $text{'ui_selall'};
return "<a class='select_all' href='#' onClick='var ff = document.forms[$form].$field; ff.checked = true; for(i=0; i<ff.length; i++) { if (!ff[i].disabled) { ff[i].checked = true; } } return false'>$text</a>";
}

=head2 select_invert_link(field, form, text)

Returns HTML for an 'Invert selection' link that uses Javascript to invert the
selection on multiple checkboxes with the same name. The parameters are :

=item field - Name of the checkbox inputs.

=item form - Index of the form on the page.

=item text - Message for the link, defaulting to 'Invert selection'.

=cut
sub select_invert_link
{
return &theme_select_invert_link(@_) if (defined(&theme_select_invert_link));
my ($field, $form, $text) = @_;
$form = int($form);
$text ||= $text{'ui_selinv'};
return "<a class='select_invert' href='#' onClick='var ff = document.forms[$form].$field; ff.checked = !ff.checked; for(i=0; i<ff.length; i++) { if (!ff[i].disabled) { ff[i].checked = !ff[i].checked; } } return false'>$text</a>";
}

=head2 select_rows_link(field, form, text, &rows)

Returns HTML for a link that uses Javascript to select rows with particular
values for their checkboxes. The parameters are :

=item field - Name of the checkbox inputs.

=item form - Index of the form on the page.

=item text - Message for the link, de

=item rows - Reference to an array of 1 or 0 values, indicating which rows to check.

=cut
sub select_rows_link
{
return &theme_select_rows_link(@_) if (defined(&theme_select_rows_link));
my ($field, $form, $text, $rows) = @_;
$form = int($form);
my $js = "var sel = { ".join(",", map { "\"".&quote_escape($_)."\":1" } @$rows)." }; ";
$js .= "for(var i=0; i<document.forms[$form].${field}.length; i++) { var r = document.forms[$form].${field}[i]; r.checked = sel[r.value]; } ";
$js .= "return false;";
return "<a href='#' onClick='$js'>$text</a>";
}

=head2 check_pid_file(file)

Given a pid file, returns the PID it contains if the process is running.

=cut
sub check_pid_file
{
open(PIDFILE, $_[0]) || return undef;
my $pid = <PIDFILE>;
close(PIDFILE);
$pid =~ /^\s*(\d+)/ || return undef;
kill(0, $1) || return undef;
return $1;
}

=head2 get_mod_lib

Return the local os-specific library name to this module. For internal use only.

=cut
sub get_mod_lib
{
my $mn = &get_module_name();
my $md = &module_root_directory($mn);
if (-r "$md/$mn-$gconfig{'os_type'}-$gconfig{'os_version'}-lib.pl") {
        return "$mn-$gconfig{'os_type'}-$gconfig{'os_version'}-lib.pl";
        }
elsif (-r "$md/$mn-$gconfig{'os_type'}-lib.pl") {
        return "$mn-$gconfig{'os_type'}-lib.pl";
        }
elsif (-r "$md/$mn-generic-lib.pl") {
        return "$mn-generic-lib.pl";
        }
else {
	return "";
	}
}

=head2 module_root_directory(module)

Given a module name, returns its root directory. On a typical Webmin install,
all modules are under the same directory - but it is theoretically possible to
have more than one.

=cut
sub module_root_directory
{
my $d = ref($_[0]) ? $_[0]->{'dir'} : $_[0];
if (@root_directories > 1) {
	foreach my $r (@root_directories) {
		if (-d "$r/$d") {
			return "$r/$d";
			}
		}
	}
return "$root_directories[0]/$d";
}

=head2 list_mime_types

Returns a list of all known MIME types and their extensions, as a list of hash
references with keys :

=item type - The MIME type, like text/plain.

=item exts - A list of extensions, like .doc and .avi.

=item desc - A human-readable description for the MIME type.

=cut
sub list_mime_types
{
if (!@list_mime_types_cache) {
	local $_;
	open(MIME, "$root_directory/mime.types");
	while(<MIME>) {
		my $cmt;
		s/\r|\n//g;
		if (s/#\s*(.*)$//g) {
			$cmt = $1;
			}
		my ($type, @exts) = split(/\s+/);
		if ($type) {
			push(@list_mime_types_cache, { 'type' => $type,
						       'exts' => \@exts,
						       'desc' => $cmt });
			}
		}
	close(MIME);
	}
return @list_mime_types_cache;
}

=head2 guess_mime_type(filename, [default])

Given a file name like xxx.gif or foo.html, returns a guessed MIME type.
The optional default parameter sets a default type of use if none is found,
which defaults to application/octet-stream.

=cut
sub guess_mime_type
{
if ($_[0] =~ /\.([A-Za-z0-9\-]+)$/) {
	my $ext = $1;
	foreach my $t (&list_mime_types()) {
		foreach my $e (@{$t->{'exts'}}) {
			return $t->{'type'} if (lc($e) eq lc($ext));
			}
		}
	}
return @_ > 1 ? $_[1] : "application/octet-stream";
}

=head2 open_tempfile([handle], file, [no-error], [no-tempfile], [safe?])

Opens a file handle for writing to a temporary file, which will only be
renamed over the real file when the handle is closed. This allows critical
files like /etc/shadow to be updated safely, even if writing fails part way
through due to lack of disk space. The parameters are :

=item handle - File handle to open, as you would use in Perl's open function.

=item file - Full path to the file to write, prefixed by > or >> to indicate over-writing or appending. In append mode, no temp file is used.

=item no-error - By default, this function will call error if the open fails. Setting this parameter to 1 causes it to return 0 on failure, and set $! with the error code.

=item no-tempfile - If set to 1, writing will be direct to the file instead of using a temporary file.

=item safe - Indicates to users in read-only mode that this write is safe and non-destructive.

=cut
sub open_tempfile
{
if (@_ == 1) {
	# Just getting a temp file
	if (!defined($main::open_tempfiles{$_[0]})) {
		$_[0] =~ /^(.*)\/(.*)$/ || return $_[0];
		my $dir = $1 || "/";
		my $tmp = "$dir/$2.webmintmp.$$";
		$main::open_tempfiles{$_[0]} = $tmp;
		push(@main::temporary_files, $tmp);
		}
	return $main::open_tempfiles{$_[0]};
	}
else {
	# Actually opening
	my ($fh, $file, $noerror, $notemp, $safe) = @_;
	$fh = &callers_package($fh);
	$main::open_tempfiles_noerror{$file} = $noerror;

	my %gaccess = &get_module_acl(undef, "");
	my $db = $gconfig{'debug_what_write'};
	if ($file =~ /\r|\n|\0/) {
		if ($noerror) { return 0; }
		else { &error("Filename contains invalid characters"); }
		}
	if (&is_readonly_mode() && $file =~ />/ && !$safe) {
		# Read-only mode .. veto all writes
		print STDERR "vetoing write to $file\n";
		return open($fh, ">$null_file");
		}
	elsif ($file =~ /^(>|>>|)nul$/i) {
		# Write to Windows null device
		&webmin_debug_log($1 eq ">" ? "WRITE" :
			  $1 eq ">>" ? "APPEND" : "READ", "nul") if ($db);
		}
	elsif ($file =~ /^(>|>>)(\/dev\/.*)/ || lc($file) eq "nul") {
		# Writes to /dev/null or TTYs don't need to be handled
		&webmin_debug_log($1 eq ">" ? "WRITE" : "APPEND", $2) if ($db);
		return open($fh, $file);
		}
	elsif ($file =~ /^>\s*(([a-zA-Z]:)?\/.*)$/ && !$notemp) {
		&webmin_debug_log("WRITE", $1) if ($db);
		# Over-writing a file, via a temp file
		$file = $1;
		$file = &translate_filename($file);
		while(-l $file) {
			# Open the link target instead
			$file = &resolve_links($file);
			}
		if (-d $file) {
			# Cannot open a directory!
			if ($noerror) { return 0; }
			else { &error("Cannot write to directory $file"); }
			}
		my @oldst = stat($file);
		my $directopen = 0;
		my $tmp = &open_tempfile($file);
		my $ex = open($fh, ">$tmp");
		if (!$ex && $! =~ /permission/i) {
			# Could not open temp file .. try opening actual file
			# instead directly
			$ex = open($fh, ">$file");
			delete($main::open_tempfiles{$file});
			$directopen = 1;
			}
		else {
			$main::open_temphandles{$fh} = $file;
			}
		if (!$ex && !$noerror) {
			&error(&text("efileopen", $file, $!));
			}
		binmode($fh);
		if (@oldst && !$directopen) {
			# Use same permissions as the file being overwritten
			chmod($oldst[2], $tmp);
			}
		return $ex;
		}
	elsif ($file =~ /^>\s*(([a-zA-Z]:)?\/.*)$/ && $notemp) {
		# Just writing direct to a file
		&webmin_debug_log("WRITE", $1) if ($db);
		$file = $1;
		$file = &translate_filename($file);
		my @old_attributes = &get_clear_file_attributes($file);
		my $ex = open($fh, ">$file");
		&reset_file_attributes($file, \@old_attributes);
		$main::open_temphandles{$fh} = $file;
		if (!$ex && !$noerror) {
			&error(&text("efileopen", $file, $!));
			}
		binmode($fh);
		return $ex;
		}
	elsif ($file =~ /^>>\s*(([a-zA-Z]:)?\/.*)$/) {
		# Appending to a file .. nothing special to do
		&webmin_debug_log("APPEND", $1) if ($db);
		$file = $1;
		$file = &translate_filename($file);
		my @old_attributes = &get_clear_file_attributes($file);
		my $ex = open($fh, ">>$file");
		&reset_file_attributes($file, \@old_attributes);
		$main::open_temphandles{$fh} = $file;
		if (!$ex && !$noerror) {
			&error(&text("efileopen", $file, $!));
			}
		binmode($fh);
		return $ex;
		}
	elsif ($file =~ /^([a-zA-Z]:)?\//) {
		# Read mode .. nothing to do here
		&webmin_debug_log("READ", $file) if ($db);
		$file = &translate_filename($file);
		return open($fh, $file);
		}
	elsif ($file eq ">" || $file eq ">>") {
		my ($package, $filename, $line) = caller;
		if ($noerror) { return 0; }
		else { &error("Missing file to open at ${package}::${filename} line $line"); }
		}
	else {
		my ($package, $filename, $line) = caller;
		&error("Unsupported file or mode $file at ${package}::${filename} line $line");
		}
	}
}

=head2 close_tempfile(file|handle)

Copies a temp file to the actual file, assuming that all writes were
successful. The handle must have been one passed to open_tempfile.

=cut
sub close_tempfile
{
my $file;
my $fh = &callers_package($_[0]);

if (defined($file = $main::open_temphandles{$fh})) {
	# Closing a handle
	my $noerror = $main::open_tempfiles_noerror{$file};
	if (!close($fh)) {
		if ($noerror) { return 0; }
		else { &error(&text("efileclose", $file, $!)); }
		}
	delete($main::open_temphandles{$fh});
	return &close_tempfile($file);
	}
elsif (defined($main::open_tempfiles{$_[0]})) {
	# Closing a file
	my $noerror = $main::open_tempfiles_noerror{$_[0]};
	&webmin_debug_log("CLOSE", $_[0]) if ($gconfig{'debug_what_write'});
	my @st = stat($_[0]);
	if (&is_selinux_enabled() && &has_command("chcon")) {
		# Set original security context
		system("chcon --reference=".quotemeta($_[0]).
		       " ".quotemeta($main::open_tempfiles{$_[0]}).
		       " >/dev/null 2>&1");
		}
	my @old_attributes = &get_clear_file_attributes($_[0]);
	if (!rename($main::open_tempfiles{$_[0]}, $_[0])) {
		if ($noerror) { return 0; }
		else { &error("Failed to replace $_[0] with $main::open_tempfiles{$_[0]} : $!"); }
		}
	if (@st) {
		# Set original permissions and ownership
		chmod($st[2], $_[0]);
		chown($st[4], $st[5], $_[0]);
		}
	&reset_file_attributes($_[0], \@old_attributes);
	delete($main::open_tempfiles{$_[0]});
	delete($main::open_tempfiles_noerror{$_[0]});
	@main::temporary_files = grep { $_ ne $main::open_tempfiles{$_[0]} } @main::temporary_files;
	if ($main::open_templocks{$_[0]}) {
		&unlock_file($_[0]);
		delete($main::open_templocks{$_[0]});
		}
	return 1;
	}
else {
	# Must be closing a handle not associated with a file
	close($_[0]);
	return 1;
	}
}

=head2 print_tempfile(handle, text, ...)

Like the normal print function, but calls &error on failure. Useful when
combined with open_tempfile, to ensure that a criticial file is never
only partially written.

=cut
sub print_tempfile
{
my ($fh, @args) = @_;
$fh = &callers_package($fh);
(print $fh @args) || &error(&text("efilewrite",
			    $main::open_temphandles{$fh} || $fh, $!));
}

=head2 is_selinux_enabled

Returns 1 if SElinux is supported on this system and enabled, 0 if not.

=cut
sub is_selinux_enabled
{
if (!defined($main::selinux_enabled_cache)) {
	my %seconfig;
	if ($gconfig{'os_type'} !~ /-linux$/) {
		# Not on linux, so no way
		$main::selinux_enabled_cache = 0;
		}
	elsif (&read_env_file("/etc/selinux/config", \%seconfig)) {
		# Use global config file
		$main::selinux_enabled_cache =
			$seconfig{'SELINUX'} eq 'disabled' ||
			!$seconfig{'SELINUX'} ? 0 : 1;
		}
	else {
		# Use selinuxenabled command
		#$selinux_enabled_cache =
		#	system("selinuxenabled >/dev/null 2>&1") ? 0 : 1;
		$main::selinux_enabled_cache = 0;
		}
	}
return $main::selinux_enabled_cache;
}

=head2 get_clear_file_attributes(file)

Finds file attributes that may prevent writing, clears them and returns them
as a list. May call error. Mainly for internal use by open_tempfile and
close_tempfile.

=cut
sub get_clear_file_attributes
{
my ($file) = @_;
my @old_attributes;
if ($gconfig{'chattr'}) {
	# Get original immutable bit
	my $out = &backquote_command(
		"lsattr ".quotemeta($file)." 2>/dev/null");
	if (!$?) {
		$out =~ s/\s\S+\n//;
		@old_attributes = grep { $_ ne '-' } split(//, $out);
		}
	if (&indexof("i", @old_attributes) >= 0) {
		my $err = &backquote_logged(
			"chattr -i ".quotemeta($file)." 2>&1");
		if ($?) {
			&error("Failed to remove immutable bit on ".
			       "$file : $err");
			}
		}
	}
return @old_attributes;
}

=head2 reset_file_attributes(file, &attributes)

Put back cleared attributes on some file. May call error. Mainly for internal
use by close_tempfile.

=cut
sub reset_file_attributes
{
my ($file, $old_attributes) = @_;
if (&indexof("i", @$old_attributes) >= 0) {
	my $err = &backquote_logged(
		"chattr +i ".quotemeta($file)." 2>&1");
	if ($?) {
		&error("Failed to restore immutable bit on ".
		       "$file : $err");
		}
	}
}

=head2 cleanup_tempnames

Remove all temporary files generated using transname. Typically only called
internally when a Webmin script exits.

=cut
sub cleanup_tempnames
{
foreach my $t (@main::temporary_files) {
	&unlink_file($t);
	}
@main::temporary_files = ( );
}

=head2 open_lock_tempfile([handle], file, [no-error])

Returns a temporary file for writing to some actual file, and also locks it.
Effectively the same as calling lock_file and open_tempfile on the same file,
but calls the unlock for you automatically when it is closed.

=cut
sub open_lock_tempfile
{
my ($fh, $file, $noerror, $notemp, $safe) = @_;
$fh = &callers_package($fh);
my $lockfile = $file;
$lockfile =~ s/^[^\/]*//;
if ($lockfile =~ /^\//) {
	while(-l $lockfile) {
		# If the file is a link, follow it so that locking is done on
		# the same file that gets unlocked later
		$lockfile = &resolve_links($lockfile);
		}
	$main::open_templocks{$lockfile} = &lock_file($lockfile);
	}
return &open_tempfile($fh, $file, $noerror, $notemp, $safe);
}

sub END
{
$main::end_exit_status ||= $?;
if ($$ == $main::initial_process_id) {
	# Exiting from initial process
	&cleanup_tempnames();
	if ($gconfig{'debug_what_start'} && $main::debug_log_start_time) {
		my $len = time() - $main::debug_log_start_time;
		&webmin_debug_log("STOP", "runtime=$len");
		$main::debug_log_start_time = 0;
		}
	if (!$ENV{'SCRIPT_NAME'}) {
		# In a command-line script - call the real exit, so that the
		# exit status gets properly propogated. In some cases this
		# was not happening.
		exit($main::end_exit_status);
		}
	}
}

=head2 month_to_number(month)

Converts a month name like feb to a number like 1.

=cut
sub month_to_number
{
return $month_to_number_map{lc(substr($_[0], 0, 3))};
}

=head2 number_to_month(number)

Converts a number like 1 to a month name like Feb.

=cut
sub number_to_month
{
return ucfirst($number_to_month_map{$_[0]});
}

=head2 get_rbac_module_acl(user, module)

Returns a hash reference of RBAC overrides ACLs for some user and module.
May return undef if none exist (indicating access denied), or the string *
if full access is granted.

=cut
sub get_rbac_module_acl
{
my ($user, $mod) = @_;
eval "use Authen::SolarisRBAC";
return undef if ($@);
my %rv;
my $foundany = 0;
if (Authen::SolarisRBAC::chkauth("webmin.$mod.admin", $user)) {
	# Automagic webmin.modulename.admin authorization exists .. allow access
	$foundany = 1;
	if (!Authen::SolarisRBAC::chkauth("webmin.$mod.config", $user)) {
		%rv = ( 'noconfig' => 1 );
		}
	else {
		%rv = ( );
		}
	}
local $_;
open(RBAC, &module_root_directory($mod)."/rbac-mapping");
while(<RBAC>) {
	s/\r|\n//g;
	s/#.*$//;
	my ($auths, $acls) = split(/\s+/, $_);
	my @auths = split(/,/, $auths);
	next if (!$auths);
	my ($merge) = ($acls =~ s/^\+//);
	my $gotall = 1;
	if ($auths eq "*") {
		# These ACLs apply to all RBAC users.
		# Only if there is some that match a specific authorization
		# later will they be used though.
		}
	else {
		# Check each of the RBAC authorizations
		foreach my $a (@auths) {
			if (!Authen::SolarisRBAC::chkauth($a, $user)) {
				$gotall = 0;
				last;
				}
			}
		$foundany++ if ($gotall);
		}
	if ($gotall) {
		# Found an RBAC authorization - return the ACLs
		return "*" if ($acls eq "*");
		my %acl = map { split(/=/, $_, 2) } split(/,/, $acls);
		if ($merge) {
			# Just add to current set
			foreach my $a (keys %acl) {
				$rv{$a} = $acl{$a};
				}
			}
		else {
			# Found final ACLs
			return \%acl;
			}
		}
	}
close(RBAC);
return !$foundany ? undef : %rv ? \%rv : undef;
}

=head2 supports_rbac([module])

Returns 1 if RBAC client support is available, such as on Solaris.

=cut
sub supports_rbac
{
return 0 if ($gconfig{'os_type'} ne 'solaris');
eval "use Authen::SolarisRBAC";
return 0 if ($@);
if ($_[0]) {
	#return 0 if (!-r &module_root_directory($_[0])."/rbac-mapping");
	}
return 1;
}

=head2 supports_ipv6()

Returns 1 if outgoing IPv6 connections can be made

=cut
sub supports_ipv6
{
return $ipv6_module_error ? 0 : 1;
}

=head2 use_rbac_module_acl(user, module)

Returns 1 if some user should use RBAC to get permissions for a module

=cut
sub use_rbac_module_acl
{
my $u = defined($_[0]) ? $_[0] : $base_remote_user;
my $m = defined($_[1]) ? $_[1] : &get_module_name();
return 1 if ($gconfig{'rbacdeny_'.$u});		# RBAC forced for user
my %access = &get_module_acl($u, $m, 1);
return $access{'rbac'} ? 1 : 0;
}

=head2 execute_command(command, stdin, stdout, stderr, translate-files?, safe?)

Runs some command, possibly feeding it input and capturing output to the
give files or scalar references. The parameters are :

=item command - Full command to run, possibly including shell meta-characters.

=item stdin - File to read input from, or a scalar ref containing input, or undef if no input should be given.

=item stdout - File to write output to, or a scalar ref into which output should be placed, or undef if the output is to be discarded.

=item stderr - File to write error output to, or a scalar ref into which error output should be placed, or undef if the error output is to be discarded.

=item translate-files - Set to 1 to apply filename translation to any filenames. Usually has no effect.

=item safe - Set to 1 if this command is safe and does not modify the state of the system.

=cut
sub execute_command
{
my ($cmd, $stdin, $stdout, $stderr, $trans, $safe) = @_;
if (&is_readonly_mode() && !$safe) {
	print STDERR "Vetoing command $_[0]\n";
	$? = 0;
	return 0;
	}
$cmd = &translate_command($cmd);

# Use ` operator where possible
&webmin_debug_log('CMD', "cmd=$cmd") if ($gconfig{'debug_what_cmd'});
if (!$stdin && ref($stdout) && !$stderr) {
	$cmd = "($cmd)" if ($gconfig{'os_type'} ne 'windows');
	$$stdout = `$cmd 2>$null_file`;
	return $?;
	}
elsif (!$stdin && ref($stdout) && $stdout eq $stderr) {
	$cmd = "($cmd)" if ($gconfig{'os_type'} ne 'windows');
	$$stdout = `$cmd 2>&1`;
	return $?;
	}
elsif (!$stdin && !$stdout && !$stderr) {
	$cmd = "($cmd)" if ($gconfig{'os_type'} ne 'windows');
	return system("$cmd >$null_file 2>$null_file <$null_file");
	}

# Setup pipes
$| = 1;		# needed on some systems to flush before forking
pipe(EXECSTDINr, EXECSTDINw);
pipe(EXECSTDOUTr, EXECSTDOUTw);
pipe(EXECSTDERRr, EXECSTDERRw);
my $pid;
if (!($pid = fork())) {
	untie(*STDIN);
	untie(*STDOUT);
	untie(*STDERR);
	open(STDIN, "<&EXECSTDINr");
	open(STDOUT, ">&EXECSTDOUTw");
	if (ref($stderr) && $stderr eq $stdout) {
		open(STDERR, ">&EXECSTDOUTw");
		}
	else {
		open(STDERR, ">&EXECSTDERRw");
		}
	$| = 1;
	close(EXECSTDINw);
	close(EXECSTDOUTr);
	close(EXECSTDERRr);

	my $fullcmd = "($cmd)";
	if ($stdin && !ref($stdin)) {
		$fullcmd .= " <$stdin";
		}
	if ($stdout && !ref($stdout)) {
		$fullcmd .= " >$stdout";
		}
	if ($stderr && !ref($stderr)) {
		if ($stderr eq $stdout) {
			$fullcmd .= " 2>&1";
			}
		else {
			$fullcmd .= " 2>$stderr";
			}
		}
	if ($gconfig{'os_type'} eq 'windows') {
		exec($fullcmd);
		}
	else {
		exec("/bin/sh", "-c", $fullcmd);
		}
	print "Exec failed : $!\n";
	exit(1);
	}
close(EXECSTDINr);
close(EXECSTDOUTw);
close(EXECSTDERRw);

# Feed input and capture output
local $_;
if ($stdin && ref($stdin)) {
	print EXECSTDINw $$stdin;
	close(EXECSTDINw);
	}
if ($stdout && ref($stdout)) {
	$$stdout = undef;
	while(<EXECSTDOUTr>) {
		$$stdout .= $_;
		}
	close(EXECSTDOUTr);
	}
if ($stderr && ref($stderr) && $stderr ne $stdout) {
	$$stderr = undef;
	while(<EXECSTDERRr>) {
		$$stderr .= $_;
		}
	close(EXECSTDERRr);
	}

# Get exit status
waitpid($pid, 0);
return $?;
}

=head2 open_readfile(handle, file)

Opens some file for reading. Returns 1 on success, 0 on failure. Pretty much
exactly the same as Perl's open function.

=cut
sub open_readfile
{
my ($fh, $file) = @_;
$fh = &callers_package($fh);
my $realfile = &translate_filename($file);
&webmin_debug_log('READ', $file) if ($gconfig{'debug_what_read'});
return open($fh, "<".$realfile);
}

=head2 open_execute_command(handle, command, output?, safe?)

Runs some command, with the specified file handle set to either write to it if
in-or-out is set to 0, or read to it if output is set to 1. The safe flag
indicates if the command modifies the state of the system or not.

=cut
sub open_execute_command
{
my ($fh, $cmd, $mode, $safe) = @_;
$fh = &callers_package($fh);
my $realcmd = &translate_command($cmd);
if (&is_readonly_mode() && !$safe) {
	# Don't actually run it
	print STDERR "vetoing command $cmd\n";
	$? = 0;
	if ($mode == 0) {
		return open($fh, ">$null_file");
		}
	else {
		return open($fh, $null_file);
		}
	}
# Really run it
&webmin_debug_log('CMD', "mode=$mode cmd=$realcmd")
	if ($gconfig{'debug_what_cmd'});
if ($mode == 0) {
	return open($fh, "| $cmd");
	}
elsif ($mode == 1) {
	return open($fh, "$cmd 2>$null_file |");
	}
elsif ($mode == 2) {
	return open($fh, "$cmd 2>&1 |");
	}
}

=head2 translate_filename(filename)

Applies all relevant registered translation functions to a filename. Mostly
for internal use, and typically does nothing.

=cut
sub translate_filename
{
my ($realfile) = @_;
my @funcs = grep { $_->[0] eq &get_module_name() ||
		   !defined($_->[0]) } @main::filename_callbacks;
foreach my $f (@funcs) {
	my $func = $f->[1];
	$realfile = &$func($realfile, @{$f->[2]});
	}
return $realfile;
}

=head2 translate_command(filename)

Applies all relevant registered translation functions to a command. Mostly
for internal use, and typically does nothing.

=cut
sub translate_command
{
my ($realcmd) = @_;
my @funcs = grep { $_->[0] eq &get_module_name() ||
		   !defined($_->[0]) } @main::command_callbacks;
foreach my $f (@funcs) {
	my $func = $f->[1];
	$realcmd = &$func($realcmd, @{$f->[2]});
	}
return $realcmd;
}

=head2 register_filename_callback(module|undef, &function, &args)

Registers some function to be called when the specified module (or all
modules) tries to open a file for reading and writing. The function must
return the actual file to open. This allows you to override which files
other code actually operates on, via the translate_filename function.

=cut
sub register_filename_callback
{
my ($mod, $func, $args) = @_;
push(@main::filename_callbacks, [ $mod, $func, $args ]);
}

=head2 register_command_callback(module|undef, &function, &args)

Registers some function to be called when the specified module (or all
modules) tries to execute a command. The function must return the actual
command to run. This allows you to override which commands other other code
actually runs, via the translate_command function.

=cut
sub register_command_callback
{
my ($mod, $func, $args) = @_;
push(@main::command_callbacks, [ $mod, $func, $args ]);
}

=head2 capture_function_output(&function, arg, ...)

Captures output that some function prints to STDOUT, and returns it. Useful
for functions outside your control that print data when you really want to
manipulate it before output.

=cut
sub capture_function_output
{
my ($func, @args) = @_;
socketpair(SOCKET2, SOCKET1, AF_UNIX, SOCK_STREAM, PF_UNSPEC);
my $old = select(SOCKET1);
my @rv = &$func(@args);
select($old);
close(SOCKET1);
my $out;
local $_;
while(<SOCKET2>) {
	$out .= $_;
	}
close(SOCKET2);
return wantarray ? ($out, \@rv) : $out;
}

=head2 capture_function_output_tempfile(&function, arg, ...)

Behaves the same as capture_function_output, but uses a temporary file
to avoid buffer full problems.

=cut
sub capture_function_output_tempfile
{
my ($func, @args) = @_;
my $temp = &transname();
open(BUFFER, ">$temp");
my $old = select(BUFFER);
my @rv = &$func(@args);
select($old);
close(BUFFER);
my $out = &read_file_contents($temp);
&unlink_file($temp);
return wantarray ? ($out, \@rv) : $out;
}

=head2 modules_chooser_button(field, multiple, [form])

Returns HTML for a button for selecting one or many Webmin modules.
field - Name of the HTML field to place the module names into.
multiple - Set to 1 if multiple modules can be selected.
form - Index of the form on the page.

=cut
sub modules_chooser_button
{
return &theme_modules_chooser_button(@_)
	if (defined(&theme_modules_chooser_button));
my $form = defined($_[2]) ? $_[2] : 0;
my $w = $_[1] ? 700 : 500;
my $h = 200;
if ($_[1] && $gconfig{'db_sizemodules'}) {
	($w, $h) = split(/x/, $gconfig{'db_sizemodules'});
	}
elsif (!$_[1] && $gconfig{'db_sizemodule'}) {
	($w, $h) = split(/x/, $gconfig{'db_sizemodule'});
	}
return "<input type=button onClick='ifield = document.forms[$form].$_[0]; chooser = window.open(\"$gconfig{'webprefix'}/module_chooser.cgi?multi=$_[1]&module=\"+escape(ifield.value), \"chooser\", \"toolbar=no,menubar=no,scrollbars=yes,width=$w,height=$h\"); chooser.ifield = ifield; window.ifield = ifield' value=\"...\">\n";
}

=head2 substitute_template(text, &hash)

Given some text and a hash reference, for each occurrence of $FOO or ${FOO} in
the text replaces it with the value of the hash key foo. Also supports blocks
like ${IF-FOO} ... ${ENDIF-FOO}, whose contents are only included if foo is
non-zero, and ${IF-FOO} ... ${ELSE-FOO} ... ${ENDIF-FOO}.

=cut
sub substitute_template
{
# Add some extra fixed parameters to the hash
my %hash = %{$_[1]};
$hash{'hostname'} = &get_system_hostname();
$hash{'webmin_config'} = $config_directory;
$hash{'webmin_etc'} = $config_directory;
$hash{'module_config'} = &get_module_variable('$module_config_directory');
$hash{'webmin_var'} = $var_directory;

# Add time-based parameters, for use in DNS
$hash{'current_time'} = time();
my @tm = localtime($hash{'current_time'});
$hash{'current_year'} = $tm[5]+1900;
$hash{'current_month'} = sprintf("%2.2d", $tm[4]+1);
$hash{'current_day'} = sprintf("%2.2d", $tm[3]);
$hash{'current_hour'} = sprintf("%2.2d", $tm[2]);
$hash{'current_minute'} = sprintf("%2.2d", $tm[1]);
$hash{'current_second'} = sprintf("%2.2d", $tm[0]);

# Actually do the substition
my $rv = $_[0];
foreach my $s (keys %hash) {
	next if ($s eq '');	# Prevent just $ from being subbed
	my $us = uc($s);
	my $sv = $hash{$s};
	my $qsv = quotemeta($sv);
	$rv =~ s/\$\{\Q$us\E\}/$sv/g;
	$rv =~ s/\$\Q$us\E/$sv/g;
	$rv =~ s/\$\{\\\Q$us\E\}/$qsv/g;
	if ($sv) {
		# Replace ${IF}..${ELSE}..${ENDIF} block with first value,
		# and ${IF}..${ENDIF} with value
		$rv =~ s/\$\{IF-\Q$us\E\}(\n?)([\000-\377]*?)\$\{ELSE-\Q$us\E\}(\n?)([\000-\377]*?)\$\{ENDIF-\Q$us\E\}(\n?)/$2/g;
		$rv =~ s/\$\{IF-\Q$us\E\}(\n?)([\000-\377]*?)\$\{ENDIF-\Q$us\E\}(\n?)/$2/g;

		# Replace $IF..$ELSE..$ENDIF block with first value,
		# and $IF..$ENDIF with value
		$rv =~ s/\$IF-\Q$us\E(\n?)([\000-\377]*?)\$ELSE-\Q$us\E(\n?)([\000-\377]*?)\$ENDIF-\Q$us\E(\n?)/$2/g;
		$rv =~ s/\$IF-\Q$us\E(\n?)([\000-\377]*?)\$ENDIF-\Q$us\E(\n?)/$2/g;

		# Replace ${IFEQ}..${ENDIFEQ} block with first value if
		# matching, nothing if not
		$rv =~ s/\$\{IFEQ-\Q$us\E-\Q$sv\E\}(\n?)([\000-\377]*?)\$\{ENDIFEQ-\Q$us\E-\Q$sv\E\}(\n?)/$2/g;
		$rv =~ s/\$\{IFEQ-\Q$us\E-[^\}]+}(\n?)([\000-\377]*?)\$\{ENDIFEQ-\Q$us\E-[^\}]+\}(\n?)//g;

		# Replace $IFEQ..$ENDIFEQ block with first value if
		# matching, nothing if not
		$rv =~ s/\$IFEQ-\Q$us\E-\Q$sv\E(\n?)([\000-\377]*?)\$ENDIFEQ-\Q$us\E-\Q$sv\E(\n?)/$2/g;
		$rv =~ s/\$IFEQ-\Q$us\E-\S+(\n?)([\000-\377]*?)\$ENDIFEQ-\Q$us\E-\S+(\n?)//g;
		}
	else {
		# Replace ${IF}..${ELSE}..${ENDIF} block with second value,
		# and ${IF}..${ENDIF} with nothing
		$rv =~ s/\$\{IF-\Q$us\E\}(\n?)([\000-\377]*?)\$\{ELSE-\Q$us\E\}(\n?)([\000-\377]*?)\$\{ENDIF-\Q$us\E\}(\n?)/$4/g;
		$rv =~ s/\$\{IF-\Q$us\E\}(\n?)([\000-\377]*?)\$\{ENDIF-\Q$us\E\}(\n?)//g;

		# Replace $IF..$ELSE..$ENDIF block with second value,
		# and $IF..$ENDIF with nothing
		$rv =~ s/\$IF-\Q$us\E(\n?)([\000-\377]*?)\$ELSE-\Q$us\E(\n?)([\000-\377]*?)\$ENDIF-\Q$us\E(\n?)/$4/g;
		$rv =~ s/\$IF-\Q$us\E(\n?)([\000-\377]*?)\$ENDIF-\Q$us\E(\n?)//g;

		# Replace ${IFEQ}..${ENDIFEQ} block with nothing
		$rv =~ s/\$\{IFEQ-\Q$us\E-[^\}]+}(\n?)([\000-\377]*?)\$\{ENDIFEQ-\Q$us\E-[^\}]+\}(\n?)//g;
		$rv =~ s/\$IFEQ-\Q$us\E-\S+(\n?)([\000-\377]*?)\$ENDIFEQ-\Q$us\E-\S+(\n?)//g;
		}
	}

# Now assume any $IF blocks whose variables are not present in the hash
# evaluate to false.
# $IF...$ELSE x $ENDIF => x
$rv =~ s/\$\{IF\-([A-Z]+)\}.*?\$\{ELSE\-\1\}(.*?)\$\{ENDIF\-\1\}/$2/gs;
# $IF...x...$ENDIF => (nothing)
$rv =~ s/\$\{IF\-([A-Z]+)\}.*?\$\{ENDIF\-\1\}//gs;
# ${var} => (nothing)
$rv =~ s/\$\{[A-Z]+\}//g;

return $rv;
}

=head2 running_in_zone

Returns 1 if the current Webmin instance is running in a Solaris zone. Used to
disable module and features that are not appropriate, like those that modify
mounted filesystems.

=cut
sub running_in_zone
{
return 0 if ($gconfig{'os_type'} ne 'solaris' ||
	     $gconfig{'os_version'} < 10);
my $zn = `zonename 2>$null_file`;
chop($zn);
return $zn && $zn ne "global";
}

=head2 running_in_vserver

Returns 1 if the current Webmin instance is running in a Linux VServer.
Used to disable modules and features that are not appropriate.

=cut
sub running_in_vserver
{
return 0 if ($gconfig{'os_type'} !~ /^\*-linux$/);
my $vserver;
local $_;
open(MTAB, "/etc/mtab");
while(<MTAB>) {
	my ($dev, $mp) = split(/\s+/, $_);
	if ($mp eq "/" && $dev =~ /^\/dev\/hdv/) {
		$vserver = 1;
		last;
		}
	}
close(MTAB);
return $vserver;
}

=head2 running_in_xen

Returns 1 if Webmin is running inside a Xen instance, by looking
at /proc/xen/capabilities.

=cut
sub running_in_xen
{
return 0 if (!-r "/proc/xen/capabilities");
my $cap = &read_file_contents("/proc/xen/capabilities");
return $cap =~ /control_d/ ? 0 : 1;
}

=head2 running_in_openvz

Returns 1 if Webmin is running inside an OpenVZ container, by looking
at /proc/vz/veinfo for a non-zero line.

=cut
sub running_in_openvz
{
return 0 if (!-r "/proc/vz/veinfo");
my $lref = &read_file_lines("/proc/vz/veinfo", 1);
return 0 if (!$lref || !@$lref);
foreach my $l (@$lref) {
	$l =~ s/^\s+//;
	my @ll = split(/\s+/, $l);
	return 0 if ($ll[0] eq '0');
	}
return 1;
}

=head2 list_categories(&modules, [include-empty])

Returns a hash mapping category codes to names, including any custom-defined
categories. The modules parameter must be an array ref of module hash objects,
as returned by get_all_module_infos.

=cut
sub list_categories
{
my ($mods, $empty) = @_;
my (%cats, %catnames);
&read_file("$config_directory/webmin.catnames", \%catnames);
foreach my $o (@lang_order_list) {
	&read_file("$config_directory/webmin.catnames.$o", \%catnames);
	}
if ($empty) {
	%cats = %catnames;
	}
foreach my $m (@$mods) {
	my $c = $m->{'category'};
	next if ($cats{$c});
	if (defined($catnames{$c})) {
		$cats{$c} = $catnames{$c};
		}
	elsif ($text{"category_$c"}) {
		$cats{$c} = $text{"category_$c"};
		}
	else {
		# try to get category name from module ..
		my %mtext = &load_language($m->{'dir'});
		if ($mtext{"category_$c"}) {
			$cats{$c} = $mtext{"category_$c"};
			}
		else {
			$c = $m->{'category'} = "";
			$cats{$c} = $text{"category_$c"};
			}
		}
	}
return %cats;
}

=head2 is_readonly_mode

Returns 1 if the current user is in read-only mode, and thus all writes
to files and command execution should fail.

=cut
sub is_readonly_mode
{
if (!defined($main::readonly_mode_cache)) {
	my %gaccess = &get_module_acl(undef, "");
	$main::readonly_mode_cache = $gaccess{'readonly'} ? 1 : 0;
	}
return $main::readonly_mode_cache;
}

=head2 command_as_user(user, with-env?, command, ...)

Returns a command to execute some command as the given user, using the
su statement. If on Linux, the /bin/sh shell is forced in case the user
does not have a valid shell. If with-env is set to 1, the - flag is added
to the su command to read the user's .profile or .bashrc file. If with-env is
set to 2, the user's shell is always used regardless. If set to 3, the user's
shell is used AND the - flag is set.

=cut
sub command_as_user
{
my ($user, $env, @args) = @_;
my @uinfo = getpwnam($user);
if ($uinfo[8] ne "/bin/sh" && $uinfo[8] !~ /\/bash$/ && $env < 2) {
	# User shell doesn't appear to be valid
	if ($gconfig{'os_type'} =~ /-linux$/) {
		# Use -s /bin/sh to force it
		$shellarg = " -s /bin/sh";
		}
	elsif ($gconfig{'os_type'} eq 'freebsd' ||
	       $gconfig{'os_type'} eq 'solaris' &&
		$gconfig{'os_version'} >= 11 ||
	       $gconfig{'os_type'} eq 'macos') {
		# Use -m and force /bin/sh
		@args = ( "/bin/sh", "-c", quotemeta(join(" ", @args)) );
		$shellarg = " -m";
		}
	}
my $rv = "su".($env == 1 || $env == 3 ? " -" : "").$shellarg.
	 " ".quotemeta($user)." -c ".quotemeta(join(" ", @args));
return $rv;
}

=head2 list_osdn_mirrors(project, file)

This function is now deprecated in favor of letting sourceforge just
redirect to the best mirror, and now just returns their primary download URL.

=cut
sub list_osdn_mirrors
{
my ($project, $file) = @_;
return ( { 'url' => "http://downloads.sourceforge.net/$project/$file",
	   'default' => 0,
	   'mirror' => 'downloads' } );
}

=head2 convert_osdn_url(url)

Given a URL like http://osdn.dl.sourceforge.net/sourceforge/project/file.zip
or http://prdownloads.sourceforge.net/project/file.zip , convert it
to a real URL on the sourceforge download redirector.

=cut
sub convert_osdn_url
{
my ($url) = @_;
if ($url =~ /^http:\/\/[^\.]+.dl.sourceforge.net\/sourceforge\/([^\/]+)\/(.*)$/ ||
    $url =~ /^http:\/\/prdownloads.sourceforge.net\/([^\/]+)\/(.*)$/) {
	# Always use the Sourceforge mail download URL, which does
	# a location-based redirect for us
	my ($project, $file) = ($1, $2);
	$url = "http://prdownloads.sourceforge.net/sourceforge/".
	       "$project/$file";
	return wantarray ? ( $url, 0 ) : $url;
	}
else {
	# Some other source .. don't change
	return wantarray ? ( $url, 2 ) : $url;
	}
}

=head2 get_current_dir

Returns the directory the current process is running in.

=cut
sub get_current_dir
{
my $out;
if ($gconfig{'os_type'} eq 'windows') {
	# Use cd command
	$out = `cd`;
	}
else {
	# Use pwd command
	$out = `pwd`;
	$out =~ s/\\/\//g;
	}
$out =~ s/\r|\n//g;
return $out;
}

=head2 supports_users

Returns 1 if the current OS supports Unix user concepts and functions like
su , getpw* and so on. This will be true on Linux and other Unixes, but false
on Windows.

=cut
sub supports_users
{
return $gconfig{'os_type'} ne 'windows';
}

=head2 supports_symlinks

Returns 1 if the current OS supports symbolic and hard links. This will not
be the case on Windows.

=cut
sub supports_symlinks
{
return $gconfig{'os_type'} ne 'windows';
}

=head2 quote_path(path)

Returns a path with safe quoting for the current operating system.

=cut
sub quote_path
{
my ($path) = @_;
if ($gconfig{'os_type'} eq 'windows' || $path =~ /^[a-z]:/i) {
	# Windows only supports "" style quoting
	return "\"$path\"";
	}
else {
	return quotemeta($path);
	}
}

=head2 get_windows_root

Returns the base windows system directory, like c:/windows.

=cut
sub get_windows_root
{
if ($ENV{'SystemRoot'}) {
	my $rv = $ENV{'SystemRoot'};
	$rv =~ s/\\/\//g;
	return $rv;
	}
else {
	return -d "c:/windows" ? "c:/windows" : "c:/winnt";
	}
}

=head2 read_file_contents(file)

Given a filename, returns its complete contents as a string. Effectively
the same as the Perl construct `cat file`.

=cut
sub read_file_contents
{
my ($file) = @_;
&open_readfile(FILE, $file) || return undef;
local $/ = undef;
my $rv = <FILE>;
close(FILE);
return $rv;
}

=head2 write_file_contents(file, data)

Writes some data to the given file

=cut
sub write_file_contents
{
my ($file, $data) = @_;
&open_tempfile(FILE, ">$file");
&print_tempfile(FILE, $data);
&close_tempfile(FILE);
}

=head2 unix_crypt(password, salt)

Performs Unix encryption on a password, using the built-in crypt function or
the Crypt::UnixCrypt module if the former does not work. The salt parameter
must be either an already-hashed password, or a two-character alpha-numeric
string.

=cut
sub unix_crypt
{
my ($pass, $salt) = @_;
return "" if ($salt !~ /^[a-zA-Z0-9\.\/]{2}/);   # same as real crypt
my $rv = eval "crypt(\$pass, \$salt)";
my $err = $@;
return $rv if ($rv && !$@);
eval "use Crypt::UnixCrypt";
if (!$@) {
	return Crypt::UnixCrypt::crypt($pass, $salt);
	}
else {
	&error("Failed to encrypt password : $err");
	}
}

=head2 split_quoted_string(string)

Given a string like I<foo "bar baz" quux>, returns the array :
foo, bar baz, quux

=cut
sub split_quoted_string
{
my ($str) = @_;
my @rv;
while($str =~ /^"([^"]*)"\s*([\000-\377]*)$/ ||
      $str =~ /^'([^']*)'\s*([\000-\377]*)$/ ||
      $str =~ /^(\S+)\s*([\000-\377]*)$/) {
	push(@rv, $1);
	$str = $2;
	}
return @rv;
}

=head2 write_to_http_cache(url, file|&data)

Updates the Webmin cache with the contents of the given file, possibly also
clearing out old data. Mainly for internal use by http_download.

=cut
sub write_to_http_cache
{
my ($url, $file) = @_;
return 0 if (!$gconfig{'cache_size'});

# Don't cache downloads that look dynamic
if ($url =~ /cgi-bin/ || $url =~ /\?/) {
	return 0;
	}

# Check if the current module should do caching
if ($gconfig{'cache_mods'} =~ /^\!(.*)$/) {
	# Caching all except some modules
	my @mods = split(/\s+/, $1);
	return 0 if (&indexof(&get_module_name(), @mods) != -1);
	}
elsif ($gconfig{'cache_mods'}) {
	# Only caching some modules
	my @mods = split(/\s+/, $gconfig{'cache_mods'});
	return 0 if (&indexof(&get_module_name(), @mods) == -1);
	}

# Work out the size
my $size;
if (ref($file)) {
	$size = length($$file);
	}
else {
	my @st = stat($file);
	$size = $st[7];
	}

if ($size > $gconfig{'cache_size'}) {
	# Bigger than the whole cache - so don't save it
	return 0;
	}
my $cfile = $url;
$cfile =~ s/\//_/g;
$cfile = "$main::http_cache_directory/$cfile";

# See how much we have cached currently, clearing old files
my $total = 0;
mkdir($main::http_cache_directory, 0700) if (!-d $main::http_cache_directory);
opendir(CACHEDIR, $main::http_cache_directory);
foreach my $f (readdir(CACHEDIR)) {
	next if ($f eq "." || $f eq "..");
	my $path = "$main::http_cache_directory/$f";
	my @st = stat($path);
	if ($gconfig{'cache_days'} &&
	    time()-$st[9] > $gconfig{'cache_days'}*24*60*60) {
		# This file is too old .. trash it
		unlink($path);
		}
	else {
		$total += $st[7];
		push(@cached, [ $path, $st[7], $st[9] ]);
		}
	}
closedir(CACHEDIR);
@cached = sort { $a->[2] <=> $b->[2] } @cached;
while($total+$size > $gconfig{'cache_size'} && @cached) {
	# Cache is too big .. delete some files until the new one will fit
	unlink($cached[0]->[0]);
	$total -= $cached[0]->[1];
	shift(@cached);
	}

# Finally, write out the new file
if (ref($file)) {
	&open_tempfile(CACHEFILE, ">$cfile");
	&print_tempfile(CACHEFILE, $$file);
	&close_tempfile(CACHEFILE);
	}
else {
	my ($ok, $err) = &copy_source_dest($file, $cfile);
	}

return 1;
}

=head2 check_in_http_cache(url)

If some URL is in the cache and valid, return the filename for it. Mainly
for internal use by http_download.

=cut
sub check_in_http_cache
{
my ($url) = @_;
return undef if (!$gconfig{'cache_size'});

# Check if the current module should do caching
if ($gconfig{'cache_mods'} =~ /^\!(.*)$/) {
	# Caching all except some modules
	my @mods = split(/\s+/, $1);
	return 0 if (&indexof(&get_module_name(), @mods) != -1);
	}
elsif ($gconfig{'cache_mods'}) {
	# Only caching some modules
	my @mods = split(/\s+/, $gconfig{'cache_mods'});
	return 0 if (&indexof(&get_module_name(), @mods) == -1);
	}

my $cfile = $url;
$cfile =~ s/\//_/g;
$cfile = "$main::http_cache_directory/$cfile";
my @st = stat($cfile);
return undef if (!@st || !$st[7]);
if ($gconfig{'cache_days'} && time()-$st[9] > $gconfig{'cache_days'}*24*60*60) {
	# Too old!
	unlink($cfile);
	return undef;
	}
open(TOUCH, ">>$cfile");	# Update the file time, to keep it in the cache
close(TOUCH);
return $cfile;
}

=head2 supports_javascript

Returns 1 if the current browser is assumed to support javascript.

=cut
sub supports_javascript
{
if (defined(&theme_supports_javascript)) {
	return &theme_supports_javascript();
	}
return $ENV{'MOBILE_DEVICE'} ? 0 : 1;
}

=head2 get_module_name

Returns the name of the Webmin module that called this function. For internal
use only by other API functions.

=cut
sub get_module_name
{
return &get_module_variable('$module_name');
}

=head2 get_module_variable(name, [ref])

Returns the value of some variable which is set in the caller's context, if
using the new WebminCore package. For internal use only.

=cut
sub get_module_variable
{
my ($v, $wantref) = @_;
my $slash = $wantref ? "\\" : "";
my $thispkg = &web_libs_package();
if ($thispkg eq 'WebminCore') {
	my ($vt, $vn) = split('', $v, 2);
	my $callpkg;
	for(my $i=0; ($callpkg) = caller($i); $i++) {
		last if ($callpkg ne $thispkg);
		}
	return eval "${slash}${vt}${callpkg}::${vn}";
	}
return eval "${slash}${v}";
}

=head2 clear_time_locale()

Temporarily force the locale to C, until reset_time_locale is called. This is
useful if your code is going to call C<strftime> from the POSIX package, and
you want to ensure that the output is in a consistent format.

=cut
sub clear_time_locale
{
if ($main::clear_time_locale_count == 0) {
	eval {
		$main::clear_time_locale_old = POSIX::setlocale(POSIX::LC_TIME);
		POSIX::setlocale(POSIX::LC_TIME, "C");
		};
	}
$main::clear_time_locale_count++;
}

=head2 reset_time_locale()

Revert the locale to whatever it was before clear_time_locale was called

=cut
sub reset_time_locale
{
if ($main::clear_time_locale_count == 1) {
	eval {
		POSIX::setlocale(POSIX::LC_TIME, $main::clear_time_locale_old);
		$main::clear_time_locale_old = undef;
		};
	}
$main::clear_time_locale_count--;
}

=head2 callers_package(filehandle)

Convert a non-module filehandle like FOO to one qualified with the
caller's caller's package, like fsdump::FOO. For internal use only.

=cut
sub callers_package
{
my ($fh) = @_;
my $callpkg = (caller(1))[0];
my $thispkg = &web_libs_package();
if (!ref($fh) && $fh !~ /::/ &&
    $callpkg ne $thispkg && $thispkg eq 'WebminCore') {
        $fh = $callpkg."::".$fh;
        }
return $fh;
}

=head2 web_libs_package()

Returns the package this code is in. We can't always trust __PACKAGE__. For
internal use only.

=cut
sub web_libs_package
{
if ($called_from_webmin_core) {
	return "WebminCore";
	}
return __PACKAGE__;
}

=head2 get_userdb_string

Returns the URL-style string for connecting to the users and groups database

=cut
sub get_userdb_string
{
return undef if ($main::no_miniserv_userdb);
my %miniserv;
&get_miniserv_config(\%miniserv);
return $miniserv{'userdb'};
}

=head2 connect_userdb(string)

Returns a handle for talking to a user database - may be a DBI or LDAP handle.
On failure returns an error message string. In an array context, returns the
protocol type too.

=cut
sub connect_userdb
{
my ($str) = @_;
my ($proto, $user, $pass, $host, $prefix, $args) = &split_userdb_string($str);
if ($proto eq "mysql") {
	# Connect to MySQL with DBI
	my $drh = eval "use DBI; DBI->install_driver('mysql');";
	$drh || return $text{'sql_emysqldriver'};
	my ($host, $port) = split(/:/, $host);
	my $cstr = "database=$prefix;host=$host";
	$cstr .= ";port=$port" if ($port);
	my $dbh = $drh->connect($cstr, $user, $pass, { });
	$dbh || return &text('sql_emysqlconnect', $drh->errstr);
	return wantarray ? ($dbh, $proto, $prefix, $args) : $dbh;
	}
elsif ($proto eq "postgresql") {
	# Connect to PostgreSQL with DBI
	my $drh = eval "use DBI; DBI->install_driver('Pg');";
	$drh || return $text{'sql_epostgresqldriver'};
	my ($host, $port) = split(/:/, $host);
	my $cstr = "dbname=$prefix;host=$host";
	$cstr .= ";port=$port" if ($port);
	my $dbh = $drh->connect($cstr, $user, $pass);
	$dbh || return &text('sql_epostgresqlconnect', $drh->errstr);
	return wantarray ? ($dbh, $proto, $prefix, $args) : $dbh;
	}
elsif ($proto eq "ldap") {
	# Connect with perl LDAP module
	eval "use Net::LDAP";
	$@ && return $text{'sql_eldapdriver'};
	my ($host, $port) = split(/:/, $host);
	my $scheme = $args->{'scheme'} || 'ldap';
	if (!$port) {
		$port = $scheme eq 'ldaps' ? 636 : 389;
		}
	my $ldap = Net::LDAP->new($host,
				  port => $port,
				  'scheme' => $scheme);
	$ldap || return &text('sql_eldapconnect', $host);
	my $mesg;
	if ($args->{'tls'}) {
		# Switch to TLS mode
		if ($args->{'tls'} eq "1_1" or $args->{'tls'} eq "1_2") {
			eval { $mesg = $ldap->start_tls(
					sslversion => "TLSv".$args->{'tls'}) };
			}
		else {
			eval { $mesg = $ldap->start_tls(); };
			}
		if ($@ || !$mesg || $mesg->code) {
			return &text('sql_eldaptls',
			    $@ ? $@ : $mesg ? $mesg->error : "Unknown error");
			}
		}
	# Login to the server
	if ($pass) {
		$mesg = $ldap->bind(dn => $user, password => $pass);
		}
	else {
		$mesg = $ldap->bind(dn => $user, anonymous => 1);
		}
	if (!$mesg || $mesg->code) {
		return &text('sql_eldaplogin', $user,
			     $mesg ? $mesg->error : "Unknown error");
		}
	return wantarray ? ($ldap, $proto, $prefix, $args) : $ldap;
	}
else {
	return "Unknown protocol $proto";
	}
}

=head2 disconnect_userdb(string, &handle)

Closes a handle opened by connect_userdb

=cut
sub disconnect_userdb
{
my ($str, $h) = @_;
if ($str =~ /^(mysql|postgresql):/) {
	# DBI disconnnect
	if (!$h->{'AutoCommit'}) {
		$h->commit();
		}
	$h->disconnect();
	}
elsif ($str =~ /^ldap:/) {
	# LDAP disconnect
	$h->unbind();
	$h->disconnect();
	}
}

=head2 split_userdb_string(string)

Converts a string like mysql://user:pass@host/db into separate parts

=cut
sub split_userdb_string
{
my ($str) = @_;
if ($str =~ /^([a-z]+):\/\/([^:]*):([^\@]*)\@([a-z0-9\.\-\_]+)\/([^\?]+)(\?(.*))?$/) {
	my ($proto, $user, $pass, $host, $prefix, $argstr) =
		($1, $2, $3, $4, $5, $7);
	my %args = map { split(/=/, $_, 2) } split(/\&/, $argstr);
	return ($proto, $user, $pass, $host, $prefix, \%args);
	}
return ( );
}

=head2 uniquelc(string, ...)

Returns the unique elements of some array using a lowercase comparison,
passed as its parameters.

=cut
sub uniquelc
{
my (%found, @rv);
foreach my $e (@_) {
	if (!$found{lc($e)}++) { push(@rv, $e); }
	}
return @rv;
}

=head2 list_combined_webmin_menu(&data, &in)

Returns an array of objects, each representing a menu item that a theme should
render such as on a left menu. Each object is a hash ref with the following
possible keys :

=item module - The Webmin module that supplied this object

=item id - A unique ID for the object

=item type - Can be "item" for a regular menu item, "cat" for a category which
             will have sub-items (members), "html" for an arbitrary HTML block,
	     "text" for a line of text, "hr" for a separator, "menu" for a
	     selector, "input" for a text box, or "title" for a desired menu
	     title.

=item desc - The text that should be displayed for the object

=item icon - Desired icon path, like /module/images/foo.gif

=item link - URL that the object should link to, for "item" types

=item members - Array ref of further objects, for the "cat" type

=item open - Set to 1 if the category should be open by default, for "cat" types

=item html - HTML to display for this object, for "html" types

=item menu - Array ref of array refs, each containing a the value and displayed
	     text for a entry in the selector when using "menu" types

=item name - For an "input" item or "menu" item, the name of the selector or
	     HTML text box

=item size - For an "item" item, desired width of the text box

=item cgi - CGI script that the "menu" or "input" type item should submit to.
	    If missing, the form submits to the same menu page.

=item target - Can be "new" for a new page, or "window" for the current whole
	       browser window

The &data parameter is a hash ref of additional information that the theme
supplies to all modules. The &in param is the CGI inputs from the menu, for
use where the menu has a form that submits to itself.

=cut
sub list_combined_webmin_menu
{
my ($data, $in) = @_;
foreach my $m (&get_available_module_infos()) {
	my $dir = &module_root_directory($m->{'dir'});
	my $mfile = "$dir/webmin_menu.pl";
	next if (!-r $mfile);
	eval {
		local $main::error_must_die = 1;
		&foreign_require($m->{'dir'}, "webmin_menu.pl");
		foreach my $i (&foreign_call($m->{'dir'}, "list_webmin_menu",
					     $data, $in)) {
			$i->{'module'} = $m->{'dir'};
			push(@rv, $i);
			}
		};
	}
return sort { ($b->{'priority'} || 0) <=> ($a->{'priority'} || 0) } @rv;
}

=head2 list_modules_webmin_menu()

This function returns a menu of Webmin modules available to the current user
and with their desired categorization method, but in the same format as
list_combined_webmin_menu for easier use by theme authors.

=cut
sub list_modules_webmin_menu
{
my @rv;
my @cats = get_visible_modules_categories();
my @catnames = map { $_->{'code'} } @cats;
if ($gconfig{"notabs_${base_remote_user}"} == 2 ||
    $gconfig{"notabs_${base_remote_user}"} == 0 && $gconfig{'notabs'}) {
	# Show modules in one list
	@rv = map { module_to_menu_item($_) }
		  (map { @{$_->{'modules'}} } @cats);
	}
else {
	# Show all modules under categories
	foreach my $c (@cats) {
		my $citem = { 'type' => 'cat',
			      'id' => $c->{'code'},
			      'desc' => $c->{'desc'},
			      'members' => [ ] };
		foreach my $minfo (@{$c->{'modules'}}) {
			push(@{$citem->{'members'}},
			     module_to_menu_item($minfo));
			}
		push(@rv, $citem);
		}
	}
return @rv;
}

=head2 module_to_menu_item(&module)

Internal function for use by list_modules_webmin_menu

=cut
sub module_to_menu_item
{
my ($minfo) = @_;
return { 'type' => 'item',
         'id' => $minfo->{'dir'},
         'desc' => $minfo->{'desc'},
         'link' => '/'.$minfo->{'dir'}.'/' };
}

=head2 list_combined_system_info(&data, &in)

Returns an array of objects, each representing a block of system information
to display. Each is a hash ref with the following keys :

=item module - The Webmin module that supplied this object

=item id - A unique ID for the object

=item type - Can be "html" for an arbitrary block of HTML, "table" for a table
	     of information, "usage" for a table of usage of some resource,
	     "redirect" for a request to redirect the whole page to another URL,
	     "warning" for a warning dialog, "link" for a link to another
	     page, or "veto" to request removal of a block from another module.

=item desc - The title for this section of info

=item open - Set to 1 if it should be displayed by default

=item table - In "table" mode, an array ref of fields to show. Each is a hash
              ref with keys described below.

=item html - In "html" mode, the raw HTML to display

=item usage - In "usage" mode, an array ref of things to show some kind of
	      usage for. Each is a hash ref with keys described below.

=item titles - In "usage" mode, an 3-element array ref of titles to show above
	       the usage columns.

=item url - In "redirect" mode, the URL to redirect the system info page to

=item warning - In "warning" mode, the HTML warning message

=item level - In "warning" mode, can be one of "success", "info", "warn" or
	      "danger"

=item link - In "link" mode, the destination URL

=item veto - In "veto" mode, the ID of the block from some other module to skip

=item target - In "link" mode, can be "new" for a new page, or "window" for the
	       current whole browser window

For "table" mode, the keys in each hash ref are :

=item desc - Label for this item

=item value - HTML to display next to the item

=item chart - Array ref for a bar chart to show, in which the first element is
	      the total size, and each subsequent element is a value to show in
	      a different color. Any leftover is assumed is filled in with the
	      final color.

=item wide - Set to 1 if this item should span a whole row

=item header - Text to show above the table

For "usage" mode, the keys in each hash ref are :

=item desc - Name of the thing for which usage is shown, like a domain

=item chart - Bar chart (as above) with usage

=item value - HTML for a description of the usage

=item header - Text to show above the usage table

The &data parameter is a hash ref of additional information that the theme
supplies to all modules. The &in param is the CGI inputs from the page, for
use where a system info block has a form that submits to itself.

=cut
sub list_combined_system_info
{
my ($data, $in) = @_;
foreach my $m (&get_all_module_infos()) {
	my $dir = &module_root_directory($m->{'dir'});
	my $mfile = "$dir/system_info.pl";
	next if (!-r $mfile);
	&foreign_require($m->{'dir'}, "system_info.pl");
	foreach my $i (&foreign_call($m->{'dir'}, "list_system_info",
				     $data, $in)) {
		$i->{'module'} = $m->{'dir'};
		push(@rv, $i);
		}
	}
if (&foreign_available("webmin")) {
	# Merge in old-style notification API
	&foreign_require("webmin");
	foreach my $n (&webmin::get_webmin_notifications()) {
		push(@rv, { 'type' => 'warning',
			    'id' => 'notifications',
			    'level' => 'warn',
			    'module' => 'webmin',
			    'warning' => $n });
		}
	}
# Obey vetos for blocks from other modules
my @vetos = grep { $_->{'type'} eq 'veto' } @rv;
foreach my $veto (@vetos) {
	my @vrv;
	foreach my $m (@rv) {
		my $v = $m->{'id'} eq $veto->{'veto'} &&
		        (!$veto->{'veto_module'} ||
		         $veto->{'veto_module'} eq $m->{'module'});
		push(@vrv, $m) if (!$v);
		}
	@rv = @vrv;
	}
@rv = grep { $_->{'type'} ne 'veto' } @rv;
return sort { ($b->{'priority'} || 0) <=> ($a->{'priority'} || 0) } @rv;
}

=head2 shell_is_bash

Returns 1 if /bin/sh is bash, 0 if not

=cut
sub shell_is_bash
{
my $bash = &has_command("bash");
if ($bash && &same_file("/bin/sh", $bash)) {
	# Symlink to /bin/bash
	return 1;
	}
my $out = &backquote_command("/bin/sh --help 2>&1 </dev/null");
if ($out =~ /GNU\s+bash/) {
	return 1;
	}
return 0;
}

=head2 compare_version_numbers(ver1, ver2)

Compares to version "number" strings, and returns -1 if ver1 is older than ver2,
0 if they are equal, or 1 if ver1 is newer than ver2.

=cut
sub compare_version_numbers
{
my ($ver1, $ver2) = @_;
my @sp1 = split(/[\.\-\+\~]/, $ver1);
my @sp2 = split(/[\.\-\+\~]/, $ver2);
my $tmp;
for(my $i=0; $i<@sp1 || $i<@sp2; $i++) {
	my $v1 = $sp1[$i];
	my $v2 = $sp2[$i];
	my $comp;
	if ($v1 =~ /^\d+$/ && $v2 =~ /^\d+$/) {
		# Numeric only
		# ie. 5 vs 7
		$comp = $v1 <=> $v2;
		}
	elsif ($v1 =~ /^(\d+[^0-9]+)(\d+)$/ && ($tmp = $1) &&
	       $v2 =~ /^(\d+[^0-9]+)(\d+)$/ &&
	       $tmp eq $1) {
		# Numeric followed by a string followed by a number, where
		# the first two components are the same
		# ie. 4ubuntu8 vs 4ubuntu10
		$v1 =~ /^(\d+[^0-9]+)(\d+)$/;
		my $num1 = $2;
		$v2 =~ /^(\d+[^0-9]+)(\d+)$/;
		my $num2 = $2;
		$comp = $num1 <=> $num2;
		}
	elsif ($v1 =~ /^\d+\S*$/ && $v2 =~ /^\d+\S*$/) {
		# Numeric followed by string
		# ie. 6redhat vs 8redhat
		$v1 =~ /^(\d+)(\S*)$/;
		my ($v1n, $v1s) = ($1, $2);
		$v2 =~ /^(\d+)(\S*)$/;
		my ($v2n, $v2s) = ($1, $2);
		$comp = $v1n <=> $v2n;
		if (!$comp) {
			# X.rcN is always older than X
			if ($v1s =~ /^rc\d+$/i && $v2s =~ /^\d*$/) {
				$comp = -1;
				}
			elsif ($v1s =~ /^\d*$/ && $v2s =~ /^rc\d+$/i) {
				$comp = 1;
				}
			else {
				$comp = $v1s cmp $v2s;
				}
			}
		}
	elsif ($v1 =~ /^(\S+[^0-9]+)(\d+)$/ && ($tmp = $1) &&
	       $v2 =~ /^(\S+[^0-9]+)(\d+)$/ &&
	       $tmp eq $1) {
		# String followed by a number, where the strings are the same
		# ie. centos7 vs centos8
		$v1 =~ /^(\S+[^0-9]+)(\d+)$/;
		my $num1 = $2;
		$v2 =~ /^(\S+[^0-9]+)(\d+)$/;
		my $num2 = $2;
		$comp = $num1 <=> $num2;
		}
	elsif ($v1 =~ /^\d+$/ && $v2 !~ /^\d+$/) {
		# Numeric compared to non-numeric - numeric is always higher
		$comp = 1;
		}
	elsif ($v1 !~ /^\d+$/ && $v2 =~ /^\d+$/) {
		# Non-numeric compared to numeric - numeric is always higher
		$comp = -1;
		}
	else {
		# String compare only
		$comp = $v1 cmp $v2;
		}
	return $comp if ($comp);
	}
return 0;
}

=head2 convert_to_json(data)

Converts the given Perl data structure to encoded binary string

=item data parameter is a hash/array reference

=cut
sub convert_to_json
{
eval "use JSON::PP";
if (!$@) {
	if (@_) {
		return JSON::PP->new->latin1->encode(@_);
		}
	else {
		return JSON::PP->new->latin1->encode({});
		}
	}
else {
	error("The JSON::PP Perl module is not available on your system : $@");
	}
}

=head2 convert_from_json(data)

Parses given JSON string

=item data parameter is encoded JSON string

=cut
sub convert_from_json
{
eval "use JSON::PP";
if (!$@) {
	my ($json_text) = @_;
	return JSON::PP->new->utf8->decode($json_text);
	}
else {
	error("The JSON::PP Perl module is not available on your system : $@");
	}
}

=head2 print_json(data)

Prints JSON data

=item data parameter is a hash/array reference

=cut
sub print_json
{
print "Content-type: application/json;\n\n";
print convert_to_json(@_);
}

$done_web_lib_funcs = 1;

1;
