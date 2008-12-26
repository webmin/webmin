=head1 web-lib-funcs.pl

Common functions for Webmin CGI scripts. This file gets in-directly included
by all scripts that use web-lib.pl.

XXX

=cut

use Socket;

use vars qw($user_risk_level $loaded_theme_library $wait_for_input
	    $done_webmin_header $trust_unknown_referers $unsafe_index_cgi
	    %done_foreign_require $webmin_feedback_address
	    $user_skill_level $pragma_no_cache $foreign_args);

=head2 read_file(file, &hash, [&order], [lowercase], [split-char])

Fill the given hash reference with name=value pairs from a file. The required
parameters are :
file - The file to head, which must be text with each line like name=value
hash - The hash reference to add values read from the file to.
order - If given, an array reference to add names to in the order they were read
lowercase - If set to 1, names are converted to lower case
split-char - If set, names and values are split on this character instead of =

=cut
sub read_file
{
local $_;
local $split = defined($_[4]) ? $_[4] : "=";
local $realfile = &translate_filename($_[0]);
&open_readfile(ARFILE, $_[0]) || return 0;
while(<ARFILE>) {
	chomp;
	local $hash = index($_, "#");
	local $eq = index($_, $split);
	if ($hash != 0 && $eq >= 0) {
		local $n = substr($_, 0, $eq);
		local $v = substr($_, $eq+1);
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
local $realfile = &translate_filename($_[0]);
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
	local %d;
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
 
=head2 write_file(file, &hash, [join-char])

Write out the contents of a hash as name=value lines. The parameters are :
file - Full path to write to
hash - A hash reference containing names and values to output
join-char - If given, names and values are separated by this instead of =

=cut
sub write_file
{
local(%old, @order);
local $join = defined($_[2]) ? $_[2] : "=";
local $realfile = &translate_filename($_[0]);
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
local $tmp = $_[0];
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
local ($tmp, $only) = @_;
if ($tmp !~ /\&[a-zA-Z]+;/ && $tmp !~ /\&#/) {
	# convert &, unless it is part of &#nnn; or &foo;
	$tmp =~ s/&([^#])/&amp;$1/g;
	}
$tmp =~ s/&$/&amp;/g;
$tmp =~ s/\"/&quot;/g if ($only eq '' || $only eq '"');
$tmp =~ s/\'/&#39;/g if ($only eq '' || $only eq "'");
return $tmp;
}

=head2 tempname([filename])

Returns a mostly random temporary file name, typically under the /tmp/.webmin
directory. If filename is given, this will be the base name used. Otherwise
a unique name is selected randomly.

=cut
sub tempname
{
local $tmp_base = $gconfig{'tempdir_'.$module_name} ?
			$gconfig{'tempdir_'.$module_name} :
		  $gconfig{'tempdir'} ? $gconfig{'tempdir'} :
		  $ENV{'TEMP'} ? $ENV{'TEMP'} :
		  $ENV{'TMP'} ? $ENV{'TMP'} :
		  -d "c:/temp" ? "c:/temp" : "/tmp/.webmin";
local $tmp_dir = -d $remote_user_info[7] && !$gconfig{'nohometemp'} ?
			"$remote_user_info[7]/.tmp" :
		 @remote_user_info ? $tmp_base."-".$remote_user :
		 $< != 0 ? $tmp_base."-".getpwuid($<) :
				     $tmp_base;
if ($gconfig{'os_type'} eq 'windows' || $tmp_dir =~ /^[a-z]:/i) {
	# On Windows system, just create temp dir if missing
	if (!-d $tmp_dir) {
		mkdir($tmp_dir, 0755) ||
			&error("Failed to create temp directory $tmp_dir : $!");
		}
	}
else {
	# On Unix systems, need to make sure temp dir is valid
	local $tries = 0;
	while($tries++ < 10) {
		local @st = lstat($tmp_dir);
		last if ($st[4] == $< && (-d _) && ($st[2] & 0777) == 0755);
		if (@st) {
			unlink($tmp_dir) || rmdir($tmp_dir) ||
				system("/bin/rm -rf ".quotemeta($tmp_dir));
			}
		mkdir($tmp_dir, 0755) || next;
		chown($<, $(, $tmp_dir);
		chmod(0755, $tmp_dir);
		}
	&error("Failed to create temp directory $tmp_dir") if ($tries >= 10);
	}
local $rv;
if (defined($_[0]) && $_[0] !~ /\.\./) {
	$rv = "$tmp_dir/$_[0]";
	}
else {
	$main::tempfilecount++;
	&seed_random();
	$rv = $tmp_dir."/".int(rand(1000000))."_".
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
local $rv = &tempname(@_);
push(@main::temporary_files, $rv);
return $rv;
}

=head2 trunc(string, maxlen)

Truncates a string to the shortest whole word less than or equal to the
given width. Useful for word wrapping.

=cut
sub trunc {
  local($str,$c);
  if (length($_[0]) <= $_[1])
    { return $_[0]; }
  $str = substr($_[0],0,$_[1]);
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
sub indexof {
  local($i);
  for($i=1; $i <= $#_; $i++) {
    if ($_[$i] eq $_[0]) { return $i - 1; }
  }
  return -1;
}

=head2 indexoflc(string, value, ...)

Like indexof, but does a case-insensitive match

=cut
sub indexoflc
{
local $str = lc(shift(@_));
local @arr = map { lc($_) } @_;
return &indexof($str, @arr);
}

=head2 sysprint(handle, [string]+)

Outputs some strings to a file handle, but bypassing IO buffering. Can be used
as a replacement for print when writing to pipes or sockets.

=cut
sub sysprint
{
local($str, $fh);
$str = join('', @_[1..$#_]);
$fh = $_[0];
syswrite $fh, $str, length($str);
}


=head2 check_ipaddress(ip)

Check if some IPv4 address is properly formatted, returning 1 if so or 0 if not

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
  local @blocks = split(/:/, $_[0]);
  return 0 if (@blocks == 0 || @blocks > 8);

  # The address/netmask format is accepted. So we're looking for a "/" to isolate a possible netmask.
  # After that, we delete the netmask to control the address only format, but we verify whether the netmask 
  # value is in [0;128].
  local $ib = $#blocks;
  local $where = index($blocks[$ib],"/");
  local $m=0;
  if ($where != -1) {
    local $b = substr($blocks[$ib],0,$where);
    $m = substr($blocks[$ib],$where+1,length($blocks[$ib])-($where+1));
    $blocks[$ib]=$b;
  }

  # The netmask must take its value in [0;128] 
  return 0 if ($m <0 || $m >128); 

  # Check the different blocks of the address : 16 bits block in hexa notation.
  # Possibility of 1 empty block or 2 if the address begins with "::".
  local $b;
  local $empty = 0;
  foreach $b (@blocks) {
	  return 0 if ($b ne "" && $b !~ /^[0-9a-f]{1,4}$/i);
	  $empty++ if ($b eq "");
	  }
  return 0 if ($empty > 1 && !($_[0] =~ /^::/ && $empty == 2));
  return 1;
}



=head2 generate_icon(image, title, link, [href], [width], [height], [before-title], [after-title])

Prints HTML for an icon image. The parameters are :
image - URL for the image, like images/foo.gif
title - Text to appear under the icon
link - Optional destination for the icon's link
href - Other HTML attributes to be added to the <a href> for the link
width - Optional width of the icon
height - Optional height of the icon
before-title - HTML to appear before the title link, but which is not actually in the link
after-title - HTML to appear after the title link, but which is not actually in the link

=cut
sub generate_icon
{
&load_theme_library();
if (defined(&theme_generate_icon)) {
	&theme_generate_icon(@_);
	return;
	}
local $w = !defined($_[4]) ? "width=48" : $_[4] ? "width=$_[4]" : "";
local $h = !defined($_[5]) ? "height=48" : $_[5] ? "height=$_[5]" : "";
if ($tconfig{'noicons'}) {
	if ($_[2]) {
		print "$_[6]<a href=\"$_[2]\" $_[3]>$_[1]</a>$_[7]\n";
		}
	else {
		print "$_[6]$_[1]$_[7]\n";
		}
	}
elsif ($_[2]) {
	print "<table border><tr><td width=48 height=48>\n",
	      "<a href=\"$_[2]\" $_[3]><img src=\"$_[0]\" alt=\"\" border=0 ",
	      "$w $h></a></td></tr></table>\n";
	print "$_[6]<a href=\"$_[2]\" $_[3]>$_[1]</a>$_[7]\n";
	}
else {
	print "<table border><tr><td width=48 height=48>\n",
	      "<img src=\"$_[0]\" alt=\"\" border=0 $w $h>",
	      "</td></tr></table>\n$_[6]$_[1]$_[7]\n";
	}
}

=head2 urlize

Converts a string to a form ok for putting in a URL, using % escaping.

=cut
sub urlize {
  local $rv = $_[0];
  $rv =~ s/([^A-Za-z0-9])/sprintf("%%%2.2X", ord($1))/ge;
  return $rv;
}

=head2 un_urlize(string)

Converts a URL-encoded string to it's original contents - the reverse of the
urlize function.

=cut
sub un_urlize
{
local $rv = $_[0];
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
local ($buf, $out, $in);
$out = $_[1];
$in = $_[0];
while(read($in, $buf, 1024) > 0) {
	(print $out $buf) || return 0;
	}
return 1;
}

=head2 ReadParseMime([maximum], [&cbfunc, &cbargs])

Read data submitted via a POST request using the multipart/form-data coding,
and store it in the global %in hash. The optional parameters are :
maximum - If the number of bytes of input exceeds this number, stop reading and call error.
cbfunc - A function reference to call after reading each block of data.
cbargs - Additional parameters to the callback function.

=cut
sub ReadParseMime
{
local ($max, $cbfunc, $cbargs) = @_;
local ($boundary, $line, $foo, $name, $got, $file);
local $err = &text('readparse_max', $max);
$ENV{'CONTENT_TYPE'} =~ /boundary=(.*)$/ || &error($text{'readparse_enc'});
if ($ENV{'CONTENT_LENGTH'} && $max && $ENV{'CONTENT_LENGTH'} > $max) {
	&error($err);
	}
&$cbfunc(0, $ENV{'CONTENT_LENGTH'}, $file, @$cbargs) if ($cbfunc);
$boundary = $1;
<STDIN>;	# skip first boundary
while(1) {
	$name = "";
	# Read section headers
	local $lastheader;
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
	if ($header{'content-disposition'} =~ /^form-data(.*)/) {
		$rest = $1;
		while ($rest =~ /([a-zA-Z]*)=\"([^\"]*)\"(.*)/) {
			if ($1 eq 'name') {
				$name = $2;
				}
			else {
				$foo = $name . "_$1";
				$in{$foo} = $2;
				}
			$rest = $3;
			}
		}
	else {
		&error($text{'readparse_cdheader'});
		}
	if ($header{'content-type'} =~ /^([^\s;]+)/) {
		$foo = $name . "_content_type";
		$in{$foo} = $1;
		}
	$file = $in{$name."_filename"};

	# Read data
	$in{$name} .= "\0" if (defined($in{$name}));
	while(1) {
		$line = <STDIN>;
		$got += length($line);
		&$cbfunc($got, $ENV{'CONTENT_LENGTH'}, $file, @$cbargs)
			if ($cbfunc);
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
		local $ptline = $line;
		$ptline =~ s/[^a-zA-Z0-9\-]/\./g;
		if (index($line, $boundary) != -1) { last; }
		$in{$name} .= $line;
		}
	chop($in{$name}); chop($in{$name});
	if (index($line,"$boundary--") != -1) { last; }
	}
&$cbfunc(-1, $ENV{'CONTENT_LENGTH'}, $file, @$cbargs) if ($cbfunc);
}

=head2 ReadParse([&hash], [method], [noplus])

Fills the given hash reference with CGI parameters, or uses the global hash
%in if none is given. Also sets the global variables $in and @in. The other
parameters are :
method - For use of this HTTP method, such as GET
noplus - Don't convert + in parameters to spaces.

=cut
sub ReadParse
{
local $a = $_[0] ? $_[0] : \%in;
%$a = ( );
local $i;
local $meth = $_[1] ? $_[1] : $ENV{'REQUEST_METHOD'};
undef($in);
if ($meth eq 'POST') {
	local $clen = $ENV{'CONTENT_LENGTH'};
	&read_fully(STDIN, \$in, $clen) == $clen ||
		&error("Failed to read POST input : $!");
	}
if ($ENV{'QUERY_STRING'}) {
	if ($in) { $in .= "&".$ENV{'QUERY_STRING'}; }
	else { $in = $ENV{'QUERY_STRING'}; }
	}
@in = split(/\&/, $in);
foreach $i (@in) {
	local ($k, $v) = split(/=/, $i, 2);
	if (!$_[2]) {
		$k =~ tr/\+/ /;
		$v =~ tr/\+/ /;
		}
	$k =~ s/%(..)/pack("c",hex($1))/ge;
	$v =~ s/%(..)/pack("c",hex($1))/ge;
	$a->{$k} = defined($a->{$k}) ? $a->{$k}."\0".$v : $v;
	}
}

=head2 read_fully(fh, &buffer, length)

Read data from some file handle up to the given length, even in the face
of partial reads. Reads the number of bytes read. Stores received data in the
string pointed to be the buffer reference.

=cut
sub read_fully
{
local ($fh, $buf, $len) = @_;
local $got = 0;
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
local ($size, $totalsize, $filename, $id) = @_;
return if ($gconfig{'no_upload_tracker'});
return if (!$id);

# Create the upload tracking directory - if running as non-root, this has to
# be under the user's home
local $vardir;
if ($<) {
	local @uinfo = @remote_user_info ? @remote_user_info : getpwuid($<);
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
	local $now = time();
	opendir(UPDIR, $vardir);
	foreach my $f (readdir(UPDIR)) {
		next if ($f !~ /^upload\./);
		local @st = stat("$vardir/$f");
		if ($st[9] < $now-3600) {
			unlink("$vardir/$f");
			}
		}
	closedir(UPDIR);
	$main::read_parse_mime_callback_flushed++;
	}

# Only update file once per percent
local $upfile = "$vardir/upload.$id";
if ($totalsize && $size >= 0) {
	local $pc = int(100 * $size / $totalsize);
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
local ($id, $fields) = @_;
return "" if ($gconfig{'no_upload_tracker'});
local $opener = "window.open(\"$gconfig{'webprefix'}/uptracker.cgi?id=$id&uid=$<\", \"uptracker\", \"toolbar=no,menubar=no,scrollbars=no,width=500,height=100\");";
if ($fields) {
	local $if = join(" || ", map { "typeof($_) != \"undefined\" && $_.value != \"\"" } @$fields);
	return "onSubmit='if ($if) { $opener }'";
	}
else {
	return "onSubmit='$opener'";
	}
}

=head2 PrintHeader(charset)

Outputs the HTTP headers for an HTML page. The optional charset parameter
can be used to set a character set. Normally this function is not called
directly, but is rather called by ui_print_header or header.

=cut
sub PrintHeader
{
if ($pragma_no_cache || $gconfig{'pragma_no_cache'}) {
	print "pragma: no-cache\n";
	print "Expires: Thu, 1 Jan 1970 00:00:00 GMT\n";
	print "Cache-Control: no-store, no-cache, must-revalidate\n";
	print "Cache-Control: post-check=0, pre-check=0\n";
	}
if (defined($_[0])) {
	print "Content-type: text/html; Charset=$_[0]\n\n";
	}
else {
	print "Content-type: text/html\n\n";
	}
}

=head2 header(title, image, [help], [config], [nomodule], [nowebmin], [rightside], [head-stuff], [body-stuff], [below])

Outputs a Webmin HTML page header with a title. The parameters are :
title - XXX

Output a page header with some title and image. The header may also
include a link to help, and a link to the config page.
The header will also have a link to to webmin index, and a link to the
module menu if there is no config link

=cut
sub header
{
return if ($main::done_webmin_header++);
local $ll;
local $charset = defined($force_charset) ? $force_charset : &get_charset();
&PrintHeader($charset);
&load_theme_library();
if (defined(&theme_header)) {
	&theme_header(@_);
	return;
	}
print "<!doctype html public \"-//W3C//DTD HTML 3.2 Final//EN\">\n";
print "<html>\n";
local $os_type = $gconfig{'real_os_type'} ? $gconfig{'real_os_type'}
					  : $gconfig{'os_type'};
local $os_version = $gconfig{'real_os_version'} ? $gconfig{'real_os_version'}
					        : $gconfig{'os_version'};
print "<head>\n";
if (defined(&theme_prehead)) {
	&theme_prehead(@_);
	}
if ($charset) {
	print "<meta http-equiv=\"Content-Type\" ",
	      "content=\"text/html; Charset=$charset\">\n";
	}
if (@_ > 0) {
	local $title;
	if ($gconfig{'sysinfo'} == 1 && $remote_user) {
		$title = sprintf "%s : %s on %s (%s %s)\n",
			$_[0], $remote_user, &get_display_hostname(),
			$os_type, $os_version;
		}
	elsif ($gconfig{'sysinfo'} == 4 && $remote_user) {
		$title = sprintf "%s on %s (%s %s)\n",
			$remote_user, &get_display_hostname(),
			$os_type, $os_version;
		}
	else {
		$title = $_[0];
		}
        if ($gconfig{'showlogin'} && $remote_user) {
            $title = $remote_user." : ".$title;
            }
        print "<title>$title</title>\n";
	print $_[7] if ($_[7]);
	if ($gconfig{'sysinfo'} == 0 && $remote_user) {
		print "<script language=JavaScript type=text/javascript>\n";
		print "defaultStatus=\"".&text('header_statusmsg',
			    ($ENV{'ANONYMOUS_USER'} ? "Anonymous user"
						   : $remote_user).
			    ($ENV{'SSL_USER'} ? " (SSL certified)" :
			     $ENV{'LOCAL_USER'} ? " (Local user)" : ""),
			    $text{'programname'},
			    &get_webmin_version(),
			    &get_display_hostname(),
			    $os_type.($os_version eq "*" ? "" :" $os_version")).
			"\";\n";
		print "</SCRIPT>\n";
		}
	}
print "$tconfig{'headhtml'}\n" if ($tconfig{'headhtml'});
if ($tconfig{'headinclude'}) {
	local $_;
	open(INC, "$theme_root_directory/$tconfig{'headinclude'}");
	while(<INC>) {
		print;
		}
	close(INC);
	}
print "</head>\n";
local $bgcolor = defined($tconfig{'cs_page'}) ? $tconfig{'cs_page'} :
		 defined($gconfig{'cs_page'}) ? $gconfig{'cs_page'} : "ffffff";
local $link = defined($tconfig{'cs_link'}) ? $tconfig{'cs_link'} :
	      defined($gconfig{'cs_link'}) ? $gconfig{'cs_link'} : "0000ee";
local $text = defined($tconfig{'cs_text'}) ? $tconfig{'cs_text'} : 
	      defined($gconfig{'cs_text'}) ? $gconfig{'cs_text'} : "000000";
local $bgimage = defined($tconfig{'bgimage'}) ? "background=$tconfig{'bgimage'}"
					      : "";
local $dir = $current_lang_info->{'dir'} ? "dir=\"$current_lang_info->{'dir'}\""
					 : "";
print "<body bgcolor=#$bgcolor link=#$link vlink=#$link text=#$text ",
      "$bgimage $tconfig{'inbody'} $dir $_[8]>\n";
if (defined(&theme_prebody)) {
	&theme_prebody(@_);
	}
local $hostname = &get_display_hostname();
local $version = &get_webmin_version();
local $prebody = $tconfig{'prebody'};
if ($prebody) {
	$prebody =~ s/%HOSTNAME%/$hostname/g;
	$prebody =~ s/%VERSION%/$version/g;
	$prebody =~ s/%USER%/$remote_user/g;
	$prebody =~ s/%OS%/$os_type $os_version/g;
	print "$prebody\n";
	}
if ($tconfig{'prebodyinclude'}) {
	local $_;
	open(INC, "$theme_root_directory/$tconfig{'prebodyinclude'}");
	while(<INC>) {
		print;
		}
	close(INC);
	}
if (@_ > 1) {
	print $tconfig{'preheader'};
	print "<table class='header' width=100%><tr>\n";
	if ($gconfig{'sysinfo'} == 2 && $remote_user) {
		print "<td id='headln1' colspan=3 align=center>\n";
		printf "%s%s logged into %s %s on %s (%s%s)</td>\n",
			$ENV{'ANONYMOUS_USER'} ? "Anonymous user" : "<tt>$remote_user</tt>",
			$ENV{'SSL_USER'} ? " (SSL certified)" :
			$ENV{'LOCAL_USER'} ? " (Local user)" : "",
			$text{'programname'},
			$version, "<tt>$hostname</tt>",
			$os_type, $os_version eq "*" ? "" : " $os_version";
		print "</td></tr> <tr>\n";
		}
	print "<td id='headln2l' width=15% valign=top align=left>";
	if ($ENV{'HTTP_WEBMIN_SERVERS'} && !$tconfig{'framed'}) {
		print "<a href='$ENV{'HTTP_WEBMIN_SERVERS'}'>",
		      "$text{'header_servers'}</a><br>\n";
		}
	if (!$_[5] && !$tconfig{'noindex'}) {
		local @avail = &get_available_module_infos(1);
		local $nolo = $ENV{'ANONYMOUS_USER'} ||
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
			print "<a href='$gconfig{'webprefix'}/?cat=$module_info{'category'}'>",
			      "$text{'header_webmin'}</a><br>\n";
			}
		}
	if (!$_[4] && !$tconfig{'nomoduleindex'}) {
		local $idx = $module_info{'index_link'};
		local $mi = $module_index_link || "/$module_name/$idx";
		local $mt = $module_index_name || $text{'header_module'};
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
		local %access = &get_module_acl();
		if (!$access{'noconfig'} && !$config{'noprefs'}) {
			local $cprog = $user_module_config_directory ?
					"uconfig.cgi" : "config.cgi";
			print "<a href=\"$gconfig{'webprefix'}/$cprog?$module_name\">",
			      $text{'header_config'},"</a><br>\n";
			}
		}
	print "</td>\n";
	if ($_[1]) {
		# Title is a single image
		print "<td id='headln2c' align=center width=70%>",
		      "<img alt=\"$_[0]\" src=\"$_[1]\"></td>\n";
		}
	else {
		# Title is just text
		local $ts = defined($tconfig{'titlesize'}) ?
				$tconfig{'titlesize'} : "+2";
		print "<td id='headln2c' align=center width=70%>",
		      ($ts ? "<font size=$ts>" : ""),$_[0],
		      ($ts ? "</font>" : "");
		print "<br>$_[9]\n" if ($_[9]);
		print "</td>\n";
		}
	print "<td id='headln2r' width=15% valign=top align=right>";
	print $_[6];
	print "</td></tr></table>\n";
	print $tconfig{'postheader'};
	}
}

=head2 popup_header([title], [head-stuff], [body-stuff])

Outputs a page header, suitable for a popup window. If no title is given,
absolutely no decorations are output (such as for use in a frameset)

=cut
sub popup_header
{
return if ($main::done_webmin_header++);
local $ll;
local $charset = defined($force_charset) ? $force_charset : &get_charset();
&PrintHeader($charset);
&load_theme_library();
if (defined(&theme_popup_header)) {
	&theme_popup_header(@_);
	return;
	}
print "<!doctype html public \"-//W3C//DTD HTML 3.2 Final//EN\">\n";
print "<html>\n";
print "<head>\n";
if (defined(&theme_popup_prehead)) {
	&theme_popup_prehead(@_);
	}
print "<title>$_[0]</title>\n";
print $_[1];
print "$tconfig{'headhtml'}\n" if ($tconfig{'headhtml'});
if ($tconfig{'headinclude'}) {
	local $_;
	open(INC, "$theme_root_directory/$tconfig{'headinclude'}");
	while(<INC>) {
		print;
		}
	close(INC);
	}
print "</head>\n";
local $bgcolor = defined($tconfig{'cs_page'}) ? $tconfig{'cs_page'} :
		 defined($gconfig{'cs_page'}) ? $gconfig{'cs_page'} : "ffffff";
local $link = defined($tconfig{'cs_link'}) ? $tconfig{'cs_link'} :
	      defined($gconfig{'cs_link'}) ? $gconfig{'cs_link'} : "0000ee";
local $text = defined($tconfig{'cs_text'}) ? $tconfig{'cs_text'} : 
	      defined($gconfig{'cs_text'}) ? $gconfig{'cs_text'} : "000000";
local $bgimage = defined($tconfig{'bgimage'}) ? "background=$tconfig{'bgimage'}"
					      : "";
print "<body id='popup' bgcolor=#$bgcolor link=#$link vlink=#$link ",
      "text=#$text $bgimage $tconfig{'inbody'} $_[2]>\n";
if (defined(&theme_popup_prebody)) {
	&theme_popup_prebody(@_);
	}
}

=head2 footer([page, name]+, [noendbody])

Output a footer for returning to some page

=cut
sub footer
{
&load_theme_library();
if (defined(&theme_footer)) {
	&theme_footer(@_);
	return;
	}
local $i;
for($i=0; $i+1<@_; $i+=2) {
	local $url = $_[$i];
	if ($url ne '/' || !$tconfig{'noindex'}) {
		if ($url eq '/') {
			$url = "/?cat=$module_info{'category'}";
			}
		elsif ($url eq '' && $module_name) {
			$url = "/$module_name/$module_info{'index_link'}";
			}
		elsif ($url =~ /^\?/ && $module_name) {
			$url = "/$module_name/$url";
			}
		$url = "$gconfig{'webprefix'}$url" if ($url =~ /^\//);
		if ($i == 0) {
			print "<a href=\"$url\"><img alt=\"<-\" align=middle border=0 src=$gconfig{'webprefix'}/images/left.gif></a>\n";
			}
		else {
			print "&nbsp;|\n";
			}
		print "&nbsp;<a href=\"$url\">",&text('main_return', $_[$i+1]),"</a>\n";
		}
	}
print "<br>\n";
if (!$_[$i]) {
	local $postbody = $tconfig{'postbody'};
	if ($postbody) {
		local $hostname = &get_display_hostname();
		local $version = &get_webmin_version();
		local $os_type = $gconfig{'real_os_type'} ?
				$gconfig{'real_os_type'} : $gconfig{'os_type'};
		local $os_version = $gconfig{'real_os_version'} ?
				$gconfig{'real_os_version'} : $gconfig{'os_version'};
		$postbody =~ s/%HOSTNAME%/$hostname/g;
		$postbody =~ s/%VERSION%/$version/g;
		$postbody =~ s/%USER%/$remote_user/g;
		$postbody =~ s/%OS%/$os_type $os_version/g;
		print "$postbody\n";
		}
	if ($tconfig{'postbodyinclude'}) {
		local $_;
		open(INC, "$theme_root_directory/$tconfig{'postbodyinclude'}");
		while(<INC>) {
			print;
			}
		close(INC);
		}
	if (defined(&theme_postbody)) {
		&theme_postbody(@_);
		}
	print "</body></html>\n";
	}
}

=head2 popup_footer

Outputs html for a footer for a popup window

=cut
sub popup_footer
{
&load_theme_library();
if (defined(&theme_popup_footer)) {
	&theme_popup_footer(@_);
	return;
	}
print "</body></html>\n";
}

=head2 load_theme_library

For internal use only

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

=head2 redirect

redirect
Output headers to redirect the browser to some page

=cut
sub redirect
{
local($port, $prot, $url);
$port = $ENV{'SERVER_PORT'} == 443 && uc($ENV{'HTTPS'}) eq "ON" ? "" :
	$ENV{'SERVER_PORT'} == 80 && uc($ENV{'HTTPS'}) ne "ON" ? "" :
		":$ENV{'SERVER_PORT'}";
$prot = uc($ENV{'HTTPS'}) eq "ON" ? "https" : "http";
local $wp = $gconfig{'webprefixnoredir'} ? undef : $gconfig{'webprefix'};
if ($_[0] =~ /^(http|https|ftp|gopher):/) {
	# Absolute URL (like http://...)
	$url = $_[0];
	}
elsif ($_[0] =~ /^\//) {
	# Absolute path (like /foo/bar.cgi)
	$url = "$prot://$ENV{'SERVER_NAME'}$port$wp$_[0]";
	}
elsif ($ENV{'SCRIPT_NAME'} =~ /^(.*)\/[^\/]*$/) {
	# Relative URL (like foo.cgi)
	$url = "$prot://$ENV{'SERVER_NAME'}$port$wp$1/$_[0]";
	}
else {
	$url = "$prot://$ENV{'SERVER_NAME'}$port/$wp$_[0]";
	}
&load_theme_library();
if (defined(&theme_redirect)) {
	&theme_redirect($_[0], $url);
	}
else {
	print "Location: $url\n\n";
	}
}

=head2 kill_byname(name, signal)

Use the command defined in the global config to find and send a signal
to a process matching some name

=cut
sub kill_byname
{
local(@pids);
@pids = &find_byname($_[0]);
return scalar(@pids) if (&is_readonly_mode());
&webmin_debug_log('KILL', "signal=$_[1] name=$_[0]")
	if ($gconfig{'debug_what_procs'});
if (@pids) { kill($_[1], @pids); return scalar(@pids); }
else { return 0; }
}

=head2 kill_byname_logged(name, signal)

Like kill_byname, but also logs the killing

=cut
sub kill_byname_logged
{
local(@pids);
@pids = &find_byname($_[0]);
return scalar(@pids) if (&is_readonly_mode());
if (@pids) { &kill_logged($_[1], @pids); return scalar(@pids); }
else { return 0; }
}

=head2 find_byname(name)

Finds a process by name, and returns a list of matching PIDs

=cut
sub find_byname
{
if ($gconfig{'os_type'} =~ /-linux$/ && -r "/proc/$$/cmdline") {
	# Linux with /proc filesystem .. use cmdline files, as this is
	# faster than forking
	local @pids;
	opendir(PROCDIR, "/proc");
	foreach my $f (readdir(PROCDIR)) {
		if ($f eq int($f) && $f != $$) {
			local $line = &read_file_contents("/proc/$f/cmdline");
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
		local @procs = &proc::list_processes();
		local @pids;
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
local($cmd, @pids);
$cmd = $gconfig{'find_pid_command'};
$cmd =~ s/NAME/"$_[0]"/g;
$cmd = &translate_command($cmd);
@pids = split(/\n/, `($cmd) <$null_file 2>$null_file`);
@pids = grep { $_ != $$ } @pids;
return @pids;
}

=head2 error([message]+)

Display an error message and exit. The variable $whatfailed must be set
to the name of the operation that failed.

=cut
sub error
{
if (!$main::error_must_die) {
	print STDERR "Error: ",@_,"\n";
	}
&load_theme_library();
if ($main::error_must_die) {
	if ($gconfig{'error_stack'}) {
		print STDERR "Error: ",@_,"\n";
		for(my $i=0; my @stack = caller($i); $i++) {
			print STDERR "File: $stack[1] Line: $stack[2] ",
				     "Function: $stack[3]\n";
			}
		}
	die @_;
	}
elsif (!$ENV{'REQUEST_METHOD'}) {
	# Show text-only error
	print STDERR "$text{'error'}\n";
	print STDERR "-----\n";
	print STDERR ($main::whatfailed ? "$main::whatfailed : " : ""),@_,"\n";
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
else {
	&header($text{'error'}, "");
	print "<hr>\n";
	print "<h3>",($main::whatfailed ? "$main::whatfailed : " : ""),@_,"</h3>\n";
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
		&footer($ENV{'HTTP_REFERER'}, $text{'error_previous'});
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

Display an error message in a popup window and exit.

=cut
sub popup_error
{
&load_theme_library();
if ($main::error_must_die) {
	die @_;
	}
elsif (defined(&theme_popup_error)) {
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

=head2 error_setup(message)

Register a message to be prepended to all error strings

=cut
sub error_setup
{
$main::whatfailed = $_[0];
}

=head2 wait_for(handle, regexp, regexp, ...)

Read from the input stream until one of the regexps matches..

=cut
sub wait_for
{
local ($c, $i, $sw, $rv, $ha); undef($wait_for_input);
if ($wait_for_debug) {
	print STDERR "wait_for(",join(",", @_),")\n";
	}
$ha = $_[0];
$codes =
"local \$hit;\n".
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

MISSING DOCUMENTATION

=cut
sub fast_wait_for
{
local($inp, $maxlen, $ha, $i, $c, $inpl);
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

Returns the full path if some command is in the path, undef if not

=cut
sub has_command
{
local($d);
if (!$_[0]) { return undef; }
if (exists($main::has_command_cache{$_[0]})) {
	return $main::has_command_cache{$_[0]};
	}
local $rv = undef;
local $slash = $gconfig{'os_type'} eq 'windows' ? '\\' : '/';
if ($_[0] =~ /^\// || $_[0] =~ /^[a-z]:[\\\/]/i) {
	# Absolute path given - just use it
	local $t = &translate_filename($_[0]);
	$rv = (-x $t && !-d _) ? $_[0] : undef;
	}
else {
	# Check each directory in the path
	local %donedir;
	foreach $d (split($path_separator, $ENV{'PATH'})) {
		next if ($donedir{$d}++);
		$d =~ s/$slash$// if ($d ne $slash);
		local $t = &translate_filename("$d/$_[0]");
		if (-x $t && !-d _) {
			$rv = $d.$slash.$_[0];
			last;
			}
		if ($gconfig{'os_type'} eq 'windows') {
			foreach my $sfx (".exe", ".com", ".bat") {
				local $t = &translate_filename("$d/$_[0]").$sfx;
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

=head2 make_date(seconds, [date-only])

Converts a Unix date/time in seconds to a human-readable form

=cut
sub make_date
{
local ($secs, $only) = @_;
local @tm = localtime($secs);
local $date;
local $fmt = $gconfig{'dateformat'} || 'dd/mon/yyyy';
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
if (!$only) {
	$date .= sprintf " %2.2d:%2.2d", $tm[2], $tm[1];
	}
return $date;
}

=head2 file_chooser_button(input, type, [form], [chroot], [addmode])

Return HTML for a file chooser button, if the browser supports Javascript.
Type values are 0 for file or directory, or 1 for directory only

=cut
sub file_chooser_button
{
return &theme_file_chooser_button(@_)
	if (defined(&theme_file_chooser_button));
local $form = defined($_[2]) ? $_[2] : 0;
local $chroot = defined($_[3]) ? $_[3] : "/";
local $add = int($_[4]);
local ($w, $h) = (400, 300);
if ($gconfig{'db_sizefile'}) {
	($w, $h) = split(/x/, $gconfig{'db_sizefile'});
	}
return "<input type=button onClick='ifield = form.$_[0]; chooser = window.open(\"$gconfig{'webprefix'}/chooser.cgi?add=$add&type=$_[1]&chroot=$chroot&file=\"+escape(ifield.value), \"chooser\", \"toolbar=no,menubar=no,scrollbars=no,resizable=yes,width=$w,height=$h\"); chooser.ifield = ifield; window.ifield = ifield' value=\"...\">\n";
}

=head2 popup_window_button(url, width, height, scrollbars?, &field-mappings)

Returns HTML for a button that will popup a chooser window of some kind. 
The field-mappings parameter is an array ref of array refs containing
- Attribute to assign field to in the popup window
- Form field name
- CGI parameter to URL for value, if any

=cut
sub popup_window_button
{
return &theme_popup_window_button(@_) if (defined(&theme_popup_window_button));
local ($url, $w, $h, $scroll, $fields) = @_;
local $scrollyn = $scroll ? "yes" : "no";
local $rv;
$rv .= "<input type=button onClick='";
foreach my $m (@$fields) {
	$rv .= "$m->[0] = form.$m->[1]; ";
	}
local $sep = $url =~ /\?/ ? "&" : "?";
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
$rv .= "' value=\"...\">";
return $rv;
}

=head2 read_acl(&array, &array)

Reads the acl file into the given associative arrays

=cut
sub read_acl
{
local($user, $_, @mods);
if (!defined(%main::acl_hash_cache)) {
	local $_;
	open(ACL, &acl_filename());
	while(<ACL>) {
		if (/^([^:]+):\s*(.*)/) {
			local(@mods);
			$user = $1;
			@mods = split(/\s+/, $2);
			foreach $m (@mods) {
				$main::acl_hash_cache{$user,$m}++;
				}
			$main::acl_array_cache{$user} = \@mods;
			}
		}
	close(ACL);
	}
if ($_[0]) { %{$_[0]} = %main::acl_hash_cache; }
if ($_[1]) { %{$_[1]} = %main::acl_array_cache; }
}

=head2 acl_filename

Returns the file containing the webmin ACL

=cut
sub acl_filename
{
return "$config_directory/webmin.acl";
}

=head2 acl_check

Does nothing, but kept around for compatability

=cut
sub acl_check
{
}

=head2 get_miniserv_config(&array)

Store miniserv configuration into the given array

=cut
sub get_miniserv_config
{
return &read_file_cached(
	$ENV{'MINISERV_CONFIG'} || "$config_directory/miniserv.conf", $_[0]);
}

=head2 put_miniserv_config(&array)

Store miniserv configuration from the given array

=cut
sub put_miniserv_config
{
&write_file($ENV{'MINISERV_CONFIG'} || "$config_directory/miniserv.conf",
	    $_[0]);
}

=head2 restart_miniserv([nowait])

Kill the old miniserv process and re-start it, then optionally waits for
it to restart.

=cut
sub restart_miniserv
{
local ($nowait) = @_;
return undef if (&is_readonly_mode());
local %miniserv;
&get_miniserv_config(\%miniserv) || return;
local $i;

if ($gconfig{'os_type'} ne 'windows') {
	# On Unix systems, we can restart with a signal
	local($pid, $addr, $i);
	$miniserv{'inetd'} && return;
	local @oldst = stat($miniserv{'pidfile'});
	open(PID, $miniserv{'pidfile'}) || &error("Failed to open PID file");
	chop($pid = <PID>);
	close(PID);
	if (!$pid) { &error("Invalid PID file"); }

	# Just signal miniserv to restart
	&kill_logged('HUP', $pid) || &error("Incorrect Webmin PID $pid");

	# Wait till new PID is written, indicating a restart
	for($i=0; $i<60; $i++) {
		sleep(1);
		local @newst = stat($miniserv{'pidfile'});
		last if ($newst[9] != $oldst[9]);
		}
	$i < 60 || &error("Webmin server did not write new PID file");

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
	# wait for miniserv to come back up
	$addr = inet_aton($miniserv{'bind'} ? $miniserv{'bind'} : "127.0.0.1");
	local $ok = 0;
	for($i=0; $i<20; $i++) {
		sleep(1);
		socket(STEST, PF_INET, SOCK_STREAM, getprotobyname("tcp"));
		local $rv = connect(STEST,
				    pack_sockaddr_in($miniserv{'port'}, $addr));
		close(STEST);
		last if ($rv && ++$ok >= 2);
		}
	$i < 20 || &error("Failed to restart Webmin server!");
	}
}

=head2 reload_miniserv

Sends a USR1 signal to the miniserv process, telling it to read-read it's
configuration files. Not all changes will be applied though, like listening
ports.

=cut
sub reload_miniserv
{
return undef if (&is_readonly_mode());
local %miniserv;
&get_miniserv_config(\%miniserv) || return;

if ($gconfig{'os_type'} ne 'windows') {
	# Send a USR1 signal to re-read the config
	local($pid, $addr, $i);
	$miniserv{'inetd'} && return;
	open(PID, $miniserv{'pidfile'}) || &error("Failed to open PID file");
	chop($pid = <PID>);
	close(PID);
	if (!$pid) { &error("Invalid PID file"); }
	&kill_logged('USR1', $pid) || &error("Incorrect Webmin PID $pid");

	# Make sure this didn't kill Webmin!
	sleep(1);
	if (!kill(0, $pid)) {
		print STDERR "USR1 signal killed Webmin - restarting\n";
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
OS supplies as parameters.

=cut
sub check_os_support
{
local $oss = $_[0]->{'os_support'};
if ($_[3] && $oss && $_[0]->{'api_os_support'}) {
	# May provide usable API
	$oss .= " ".$_[0]->{'api_os_support'};
	}
if ($_[0]->{'nozone'} && &running_in_zone()) {
	# Not supported in a Solaris Zone
	return 0;
	}
if ($_[0]->{'novserver'} && &running_in_vserver()) {
	# Not supported in a Linux vserver
	return 0;
	}
return 1 if (!$oss || $oss eq '*');
local $osver = $_[2] || $gconfig{'os_version'};
local $ostype = $_[1] || $gconfig{'os_type'};
local $anyneg = 0;
while(1) {
	local ($os, $ver, $codes);
	local ($neg) = ($oss =~ s/^!//);	# starts with !
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

Download data from a HTTP url to a local file

=cut
sub http_download
{
local ($host, $port, $page, $dest, $error, $cbfunc, $ssl, $user, $pass,
       $timeout, $osdn, $nocache, $headers) = @_;
if ($gconfig{'debug_what_net'}) {
	&webmin_debug_log('HTTP', "host=$host port=$port page=$page ssl=$ssl".
				  ($user ? " user=$user pass=$pass" : "").
				  (ref($dest) ? "" : " dest=$dest"));
	}
if ($osdn) {
	# Convert OSDN URL first
	local $prot = $ssl ? "https://" : "http://";
	local $portstr = $ssl && $port == 443 ||
			 !$ssl && $port == 80 ? "" : ":$port";
	($host, $port, $page, $ssl) = &parse_http_url(
		&convert_osdn_url($prot.$host.$portstr.$page));
	}

# Check if we already have cached the URL
local $url = ($ssl ? "https://" : "http://").$host.":".$port.$page;
local $cfile = &check_in_http_cache($url);
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
local @headers;
push(@headers, [ "Host", $host ]);
push(@headers, [ "User-agent", "Webmin" ]);
if ($user) {
	local $auth = &encode_base64("$user:$pass");
	$auth =~ tr/\r\n//d;
	push(@headers, [ "Authorization", "Basic $auth" ]);
	}
foreach my $hname (keys %$headers) {
	push(@headers, [ $hname, $headers->{$hname} ]);
	}

# Actually download it
$download_timed_out = undef;
local $SIG{ALRM} = "download_timeout";
alarm($timeout || 60);
local $h = &make_http_connection($host, $port, $ssl, "GET", $page, \@headers);
alarm(0);
$h = $download_timed_out if ($download_timed_out);
if (!ref($h)) {
	if ($error) { $$error = $h; return; }
	else { &error($h); }
	}
&complete_http_download($h, $dest, $error, $cbfunc, $osdn, $host, $port,
			$headers);
if ((!$error || !$$error) && !$nocache) {
	&write_to_http_cache($url, $dest);
	}
}

=head2 complete_http_download(handle, destfile, [&error], [&callback], [osdn], [oldhost], [oldport], [&send-headers])

Do a HTTP download, after the headers have been sent

=cut
sub complete_http_download
{
local($line, %header, @headers, $s);
local $cbfunc = $_[3];

# read headers
alarm(60);
($line = &read_http_connection($_[0])) =~ tr/\r\n//d;
if ($line !~ /^HTTP\/1\..\s+(200|303|302|301)(\s+|$)/) {
	alarm(0);
	if ($_[2]) { ${$_[2]} = $line; return; }
	else { &error("Download failed : $line"); }
	}
local $rcode = $1;
&$cbfunc(1, $rcode == 303 || $rcode == 302 || $rcode == 301 ? 1 : 0)
	if ($cbfunc);
while(1) {
	$line = &read_http_connection($_[0]);
	$line =~ tr/\r\n//d;
	$line =~ /^(\S+):\s+(.*)$/ || last;
	$header{lc($1)} = $2;
	push(@headers, [ lc($1), $2 ]);
	}
alarm(0);
if ($download_timed_out) {
	if ($_[2]) { ${$_[2]} = $download_timed_out; return 0; }
	else { &error($download_timed_out); }
	}
&$cbfunc(2, $header{'content-length'}) if ($cbfunc);
if ($rcode == 303 || $rcode == 302 || $rcode == 301) {
	# follow the redirect
	&$cbfunc(5, $header{'location'}) if ($cbfunc);
	local ($host, $port, $page);
	if ($header{'location'} =~ /^http:\/\/([^:]+):(\d+)(\/.*)?$/) {
		$host = $1; $port = $2; $page = $3 || "/";
		}
	elsif ($header{'location'} =~ /^http:\/\/([^:\/]+)(\/.*)?$/) {
		$host = $1; $port = 80; $page = $2 || "/";
		}
	elsif ($header{'location'} =~ /^\// && $_[5]) {
		# Relative to same server
		$host = $_[5];
		$port = $_[6];
		$page = $header{'location'};
		}
	elsif ($header{'location'}) {
		# Assume relative to same dir
		if ($_[2]) { ${$_[2]} = "Invalid Location header $header{'location'}"; return; }
		else { &error("Invalid Location header $header{'location'}"); }
		}
	else {
		if ($_[2]) { ${$_[2]} = "Missing Location header"; return; }
		else { &error("Missing Location header"); }
		}
	&http_download($host, $port, $page, $_[1], $_[2], $cbfunc, undef,
		       undef, undef, undef, $_[4], 0, $_[7]);
	}
else {
	# read data
	if (ref($_[1])) {
		# Append to a variable
		while(defined($buf = &read_http_connection($_[0], 1024))) {
			${$_[1]} .= $buf;
			&$cbfunc(3, length(${$_[1]})) if ($cbfunc);
			}
		}
	else {
		# Write to a file
		local $got = 0;
		if (!&open_tempfile(PFILE, ">$_[1]", 1)) {
			if ($_[2]) { ${$_[2]} = "Failed to write to $_[1] : $!"; return; }
			else { &error("Failed to write to $_[1] : $!"); }
			}
		binmode(PFILE);		# For windows
		while(defined($buf = &read_http_connection($_[0], 1024))) {
			&print_tempfile(PFILE, $buf);
			$got += length($buf);
			&$cbfunc(3, $got) if ($cbfunc);
			}
		&close_tempfile(PFILE);
		if ($header{'content-length'} &&
		    $got != $header{'content-length'}) {
			if ($_[2]) { ${$_[2]} = "Download incomplete"; return; }
			else { &error("Download incomplete"); }
			}
		}
	&$cbfunc(4) if ($cbfunc);
	}
&close_http_connection($_[0]);
}


=head2 ftp_download(host, file, destfile, [&error], [&callback], [user, pass], [port])

Download data from an FTP site to a local file

=cut
sub ftp_download
{
local ($host, $file, $dest, $error, $cbfunc, $user, $pass, $port) = @_;
$port ||= 21;
if ($gconfig{'debug_what_net'}) {
	&webmin_debug_log('FTP', "host=$host port=$port file=$file".
				 ($user ? " user=$user pass=$pass" : "").
				 (ref($dest) ? "" : " dest=$dest"));
	}
local($buf, @n);
local $cbfunc = $_[4];
if (&is_readonly_mode()) {
	if ($_[3]) { ${$_[3]} = "FTP connections not allowed in readonly mode";
		     return 0; }
	else { &error("FTP connections not allowed in readonly mode"); }
	}

# Check if we already have cached the URL
local $url = "ftp://".$host.$file;
local $cfile = &check_in_http_cache($url);
if ($cfile) {
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
$download_timed_out = undef;
local $SIG{ALRM} = "download_timeout";
alarm(60);
local $connected;
if ($gconfig{'ftp_proxy'} =~ /^http:\/\/(\S+):(\d+)/ && !&no_proxy($_[0])) {
	# download through http-style proxy
	local $error;
	if (&open_socket($1, $2, "SOCK", \$error)) {
		# Connected OK
		if ($download_timed_out) {
			alarm(0);
			if ($_[3]) { ${$_[3]} = $download_timed_out; return 0; }
			else { &error($download_timed_out); }
			}
		local $esc = $_[1]; $esc =~ s/ /%20/g;
		local $up = "$_[5]:$_[6]\@" if ($_[5]);
		local $portstr = $port == 21 ? "" : ":$port";
		print SOCK "GET ftp://$up$_[0]$portstr$esc HTTP/1.0\r\n";
		print SOCK "User-agent: Webmin\r\n";
		if ($gconfig{'proxy_user'}) {
			local $auth = &encode_base64(
			   "$gconfig{'proxy_user'}:$gconfig{'proxy_pass'}");
			$auth =~ tr/\r\n//d;
			print SOCK "Proxy-Authorization: Basic $auth\r\n";
			}
		print SOCK "\r\n";
		&complete_http_download({ 'fh' => "SOCK" }, $_[2], $_[3], $_[4]);
		$connected = 1;
		}
	elsif (!$gconfig{'proxy_fallback'}) {
		alarm(0);
		if ($error) { $$error = $download_timed_out; return 0; }
		else { &error($download_timed_out); }
		}
	}

if (!$connected) {
	# connect to host and login with real FTP protocol
	&open_socket($_[0], $port, "SOCK", $_[3]) || return 0;
	alarm(0);
	if ($download_timed_out) {
		if ($_[3]) { ${$_[3]} = $download_timed_out; return 0; }
		else { &error($download_timed_out); }
		}
	&ftp_command("", 2, $_[3]) || return 0;
	if ($_[5]) {
		# Login as supplied user
		local @urv = &ftp_command("USER $_[5]", [ 2, 3 ], $_[3]);
		@urv || return 0;
		if (int($urv[1]/100) == 3) {
			&ftp_command("PASS $_[6]", 2, $_[3]) || return 0;
			}
		}
	else {
		# Login as anonymous
		local @urv = &ftp_command("USER anonymous", [ 2, 3 ], $_[3]);
		@urv || return 0;
		if (int($urv[1]/100) == 3) {
			&ftp_command("PASS root\@".&get_system_hostname(), 2,
				     $_[3]) || return 0;
			}
		}
	&$cbfunc(1, 0) if ($cbfunc);

	# get the file size and tell the callback
	&ftp_command("TYPE I", 2, $_[3]) || return 0;
	local $size = &ftp_command("SIZE $_[1]", 2, $_[3]);
	defined($size) || return 0;
	if ($cbfunc) {
		&$cbfunc(2, int($size));
		}

	# request the file
	local $pasv = &ftp_command("PASV", 2, $_[3]);
	defined($pasv) || return 0;
	$pasv =~ /\(([0-9,]+)\)/;
	@n = split(/,/ , $1);
	&open_socket("$n[0].$n[1].$n[2].$n[3]", $n[4]*256 + $n[5], "CON", $_[3]) || return 0;
	&ftp_command("RETR $_[1]", 1, $_[3]) || return 0;

	# transfer data
	local $got = 0;
	open(PFILE, "> $_[2]");
	while(read(CON, $buf, 1024) > 0) {
		print PFILE $buf;
		$got += length($buf);
		&$cbfunc(3, $got) if ($cbfunc);
		}
	close(PFILE);
	close(CON);
	if ($got != $size) {
		if ($_[3]) { ${$_[3]} = "Download incomplete"; return 0; }
		else { &error("Download incomplete"); }
		}
	&$cbfunc(4) if ($cbfunc);

	# finish off..
	&ftp_command("", 2, $_[3]) || return 0;
	&ftp_command("QUIT", 2, $_[3]) || return 0;
	close(SOCK);
	}

&write_to_http_cache($url, $dest);
return 1;
}

=head2 ftp_upload(host, file, srcfile, [&error], [&callback], [user, pass], [port])

Upload data from a local file to an FTP site

=cut
sub ftp_upload
{
local($buf, @n);
local $cbfunc = $_[4];
if (&is_readonly_mode()) {
	if ($_[3]) { ${$_[3]} = "FTP connections not allowed in readonly mode";
		     return 0; }
	else { &error("FTP connections not allowed in readonly mode"); }
	}

$download_timed_out = undef;
local $SIG{ALRM} = "download_timeout";
alarm(60);

# connect to host and login
&open_socket($_[0], $_[7] || 21, "SOCK", $_[3]) || return 0;
alarm(0);
if ($download_timed_out) {
	if ($_[3]) { ${$_[3]} = $download_timed_out; return 0; }
	else { &error($download_timed_out); }
	}
&ftp_command("", 2, $_[3]) || return 0;
if ($_[5]) {
	# Login as supplied user
	local @urv = &ftp_command("USER $_[5]", [ 2, 3 ], $_[3]);
	@urv || return 0;
	if (int($urv[1]/100) == 3) {
		&ftp_command("PASS $_[6]", 2, $_[3]) || return 0;
		}
	}
else {
	# Login as anonymous
	local @urv = &ftp_command("USER anonymous", [ 2, 3 ], $_[3]);
	@urv || return 0;
	if (int($urv[1]/100) == 3) {
		&ftp_command("PASS root\@".&get_system_hostname(), 2,
			     $_[3]) || return 0;
		}
	}
&$cbfunc(1, 0) if ($cbfunc);

&ftp_command("TYPE I", 2, $_[3]) || return 0;

# get the file size and tell the callback
local @st = stat($_[2]);
if ($cbfunc) {
	&$cbfunc(2, $st[7]);
	}

# send the file
local $pasv = &ftp_command("PASV", 2, $_[3]);
defined($pasv) || return 0;
$pasv =~ /\(([0-9,]+)\)/;
@n = split(/,/ , $1);
&open_socket("$n[0].$n[1].$n[2].$n[3]", $n[4]*256 + $n[5], "CON", $_[3]) || return 0;
&ftp_command("STOR $_[1]", 1, $_[3]) || return 0;

# transfer data
local $got;
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

Checks if some host is on the no proxy list

=cut
sub no_proxy
{
local $ip = &to_ipaddress($_[0]);
foreach $n (split(/\s+/, $gconfig{'noproxy'})) {
	return 1 if ($_[0] =~ /\Q$n\E/ ||
		     $ip =~ /\Q$n\E/);
	}
return 0;
}

=head2 open_socket(host, port, handle, [&error])

Open a TCP connection to some host and port, using a file handle.
Either calls error or modifies &error if something goes wrong.

=cut
sub open_socket
{
local($addr, $h); $h = $_[2];
if ($gconfig{'debug_what_net'}) {
	&webmin_debug_log('TCP', "host=$_[0] port=$_[1]");
	}
if (!socket($h, PF_INET, SOCK_STREAM, getprotobyname("tcp"))) {
	if ($_[3]) { ${$_[3]} = "Failed to create socket : $!"; return 0; }
	else { &error("Failed to create socket : $!"); }
	}
if (!($addr = inet_aton($_[0]))) {
	if ($_[3]) { ${$_[3]} = "Failed to lookup IP address for $_[0]"; return 0; }
	else { &error("Failed to lookup IP address for $_[0]"); }
	}
if ($gconfig{'bind_proxy'}) {
	if (!bind($h, pack_sockaddr_in(0, inet_aton($gconfig{'bind_proxy'})))) {
		if ($_[3]) { ${$_[3]} = "Failed to bind to source address : $!"; return 0; }
		else { &error("Failed to bind to source address : $!"); }
		}
	}
if (!connect($h, pack_sockaddr_in($_[1], $addr))) {
	if ($_[3]) { ${$_[3]} = "Failed to connect to $_[0]:$_[1] : $!"; return 0; }
	else { &error("Failed to connect to $_[0]:$_[1] : $!"); }
	}
local $old = select($h); $| =1; select($old);
return 1;
}


=head2 download_timeout

Called when a download times out

=cut
sub download_timeout
{
$download_timed_out = "Download timed out";
}


=head2 ftp_command(command, expected, [&error])

Send an FTP command, and die if the reply is not what was expected

=cut
sub ftp_command
{
local($line, $rcode, $reply, $c);
$what = $_[0] ne "" ? "<i>$_[0]</i>" : "initial connection";
if ($_[0] ne "") {
        print SOCK "$_[0]\r\n";
        }
alarm(60);
if (!($line = <SOCK>)) {
	alarm(0);
	if ($_[2]) { ${$_[2]} = "Failed to read reply to $what"; return undef; }
	else { &error("Failed to read reply to $what"); }
        }
$line =~ /^(...)(.)(.*)$/;
local $found = 0;
if (ref($_[1])) {
	foreach $c (@{$_[1]}) {
		$found++ if (int($1/100) == $c);
		}
	}
else {
	$found++ if (int($1/100) == $_[1]);
	}
if (!$found) {
	alarm(0);
	if ($_[2]) { ${$_[2]} = "$what failed : $3"; return undef; }
	else { &error("$what failed : $3"); }
	}
$rcode = $1; $reply = $3;
if ($2 eq "-") {
        # Need to skip extra stuff..
        while(1) {
                if (!($line = <SOCK>)) {
			alarm(0);
			if ($_[2]) { ${$_[2]} = "Failed to read reply to $what";
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

Converts a hostname to an a.b.c.d format IP address

=cut
sub to_ipaddress
{
if (&check_ipaddress($_[0])) {
	return $_[0];
	}
else {
	local $hn = gethostbyname($_[0]);
	return undef if (!$hn);
	local @ip = unpack("CCCC", $hn);
	return join("." , @ip);
	}
}

=head2 icons_table(&links, &titles, &icons, [columns], [href], [width], [height])

&befores, &afters)
Renders a 4-column table of icons

=cut
sub icons_table
{
&load_theme_library();
if (defined(&theme_icons_table)) {
	&theme_icons_table(@_);
	return;
	}
local ($i, $need_tr);
local $cols = $_[3] ? $_[3] : 4;
local $per = int(100.0 / $cols);
print "<table class='icons_table' width=100% cellpadding=5>\n";
for($i=0; $i<@{$_[0]}; $i++) {
	if ($i%$cols == 0) { print "<tr>\n"; }
	print "<td width=$per% align=center valign=top>\n";
	&generate_icon($_[2]->[$i], $_[1]->[$i], $_[0]->[$i],
		       ref($_[4]) ? $_[4]->[$i] : $_[4], $_[5], $_[6],
		       $_[7]->[$i], $_[8]->[$i]);
	print "</td>\n";
        if ($i%$cols == $cols-1) { print "</tr>\n"; }
        }
while($i++%$cols) { print "<td width=$per%></td>\n"; $need_tr++; }
print "</tr>\n" if ($need_tr);
print "</table>\n";
}

=head2 replace_file_line(file, line, [newline]*)

Replaces one line in some file with 0 or more new lines

=cut
sub replace_file_line
{
local(@lines);
local $realfile = &translate_filename($_[0]);
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
is called.

=cut
sub read_file_lines
{
if (!$_[0]) {
	local ($package, $filename, $line) = caller;
	print STDERR "Missing file to read at ${package}::${filename} line $line\n";
	}
local $realfile = &translate_filename($_[0]);
if (!$main::file_cache{$realfile}) {
        local(@lines, $_, $eol);
	&webmin_debug_log('READ', $_[0]) if ($gconfig{'debug_what_read'});
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
	$main::file_cache_noflush{$realfile} = $_[1];
	$main::file_cache_eol{$realfile} = $eol || "\n";
        }
else {
	# Make read-write if currently readonly
	if (!$_[1]) {
		$main::file_cache_noflush{$realfile} = 0;
		}
	}
return $main::file_cache{$realfile};
}

=head2 flush_file_lines([file], [eol])

Write out to a file previously read by read_file_lines to disk (except
for those marked readonly).

=cut
sub flush_file_lines
{
local $f;
local @files;
if ($_[0]) {
	local $trans = &translate_filename($_[0]);
	$main::file_cache{$trans} ||
		&error("flush_file_lines called on non-loaded file $trans");
	push(@files, $trans);
	}
else {
	@files = ( keys %main::file_cache );
	}
foreach $f (@files) {
	local $eol = $_[1] || $main::file_cache_eol{$f} || "\n";
	if (!$main::file_cache_noflush{$f}) {
		&open_tempfile(FLUSHFILE, ">$f");
		local $line;
		foreach $line (@{$main::file_cache{$f}}) {
			(print FLUSHFILE $line,$eol) ||
				&error(&text("efilewrite", $f, $!));
			}
		&close_tempfile(FLUSHFILE);
		}
	delete($main::file_cache{$f});
	delete($main::file_cache_noflush{$f});
        }
}

=head2 unflush_file_lines(file)

Clear the internal cache of some file

=cut
sub unflush_file_lines
{
local $realfile = &translate_filename($_[0]);
delete($main::file_cache{$realfile});
delete($main::file_cache_noflush{$realfile});
}

=head2 unix_user_input(fieldname, user, [form])

Returns HTML for an input to select a Unix user

=cut
sub unix_user_input
{
return "<input name=$_[0] size=13 value=\"$_[1]\"> ".
       &user_chooser_button($_[0], 0, $_[2] || 0)."\n";
}

=head2 unix_group_input(fieldname, user, [form])

Returns HTML for an input to select a Unix group

=cut
sub unix_group_input
{
return "<input name=$_[0] size=13 value=\"$_[1]\"> ".
       &group_chooser_button($_[0], 0, $_[2] || 0)."\n";
}

=head2 hlink(text, page, [module], [width], [height])

MISSING DOCUMENTATION

=cut
sub hlink
{
if (defined(&theme_hlink)) {
	return &theme_hlink(@_);
	}
local $mod = $_[2] ? $_[2] : $module_name;
local $width = $_[3] || $tconfig{'help_width'} || $gconfig{'help_width'} || 400;
local $height = $_[4] || $tconfig{'help_height'} || $gconfig{'help_height'} || 300;
return "<a onClick='window.open(\"$gconfig{'webprefix'}/help.cgi/$mod/$_[1]\", \"help\", \"toolbar=no,menubar=no,scrollbars=yes,width=$width,height=$height,resizable=yes\"); return false' href=\"$gconfig{'webprefix'}/help.cgi/$mod/$_[1]\">$_[0]</a>";
}

=head2 user_chooser_button(field, multiple, [form])

Returns HTML for a javascript button for choosing a Unix user or users

=cut
sub user_chooser_button
{
return undef if (!&supports_users());
return &theme_user_chooser_button(@_)
	if (defined(&theme_user_chooser_button));
local $form = defined($_[2]) ? $_[2] : 0;
local $w = $_[1] ? 500 : 300;
local $h = 200;
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

=cut
sub group_chooser_button
{
return undef if (!&supports_users());
return &theme_group_chooser_button(@_)
	if (defined(&theme_group_chooser_button));
local $form = defined($_[2]) ? $_[2] : 0;
local $w = $_[1] ? 500 : 300;
local $h = 200;
if ($_[1] && $gconfig{'db_sizeusers'}) {
	($w, $h) = split(/x/, $gconfig{'db_sizeusers'});
	}
elsif (!$_[1] && $gconfig{'db_sizeuser'}) {
	($w, $h) = split(/x/, $gconfig{'db_sizeuser'});
	}
return "<input type=button onClick='ifield = form.$_[0]; chooser = window.open(\"$gconfig{'webprefix'}/group_chooser.cgi?multi=$_[1]&group=\"+escape(ifield.value), \"chooser\", \"toolbar=no,menubar=no,scrollbars=yes,resizable=yes,width=$w,height=$h\"); chooser.ifield = ifield; window.ifield = ifield' value=\"...\">\n";
}

=head2 foreign_check(module, [api-only])

Checks if some other module exists and is supported on this OS

=cut
sub foreign_check
{
local ($mod, $api) = @_;
local %minfo;
local $mdir = &module_root_directory($mod);
&read_file_cached("$mdir/module.info", \%minfo) || return 0;
return &check_os_support(\%minfo, undef, undef, $api);
}

=head2 foreign_exists(module)

Checks if some other module exists

=cut
sub foreign_exists
{
local $mdir = &module_root_directory($_[0]);
return -r "$mdir/module.info";
}

=head2 foreign_available(module)

Returns 1 if some module is installed, and acessible to the current user

=cut
sub foreign_available
{
return 0 if (!&foreign_check($_[0]) &&
	     !$gconfig{'available_even_if_no_support'});
local %module_info = &get_module_info($_[0]);

# Check list of allowed modules
local %acl;
&read_acl(\%acl, undef);
return 0 if (!$acl{$base_remote_user,$_[0]} &&
	     !$acl{$base_remote_user,'*'});

# Check for usermod restrictions
local @usermods = &list_usermods();
return 0 if (!&available_usermods( [ \%module_info ], \@usermods));

if (&get_product_name() eq "webmin") {
	# Check if the user has any RBAC privileges in this module
	if (&supports_rbac($_[0]) &&
	    &use_rbac_module_acl(undef, $_[0])) {
		# RBAC is enabled for this user and module - check if he
		# has any rights
		local $rbacs = &get_rbac_module_acl(
				$remote_user, $_[0]);
		return 0 if (!$rbacs);
		}
	elsif ($gconfig{'rbacdeny_'.$u}) {
		# If denying access to modules not specifically allowed by
		# RBAC, then prevent access
		return 0;
		}
	}

# Check readonly support
if (&is_readonly_mode()) {
	return 0 if (!$module_info{'readonly'});
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

=head2 foreign_require(module, file, [package])

Brings in functions from another module

=cut
sub foreign_require
{
local $pkg = $_[2] || $_[0] || "global";
$pkg =~ s/[^A-Za-z0-9]/_/g;
return 1 if ($main::done_foreign_require{$pkg,$_[1]}++);
local @OLDINC = @INC;
local $mdir = &module_root_directory($_[0]);
@INC = &unique($mdir, @INC);
-d $mdir || &error("module $_[0] does not exist");
if (!$module_name && $_[0]) {
	chdir($mdir);
	}
local $old_fmn = $ENV{'FOREIGN_MODULE_NAME'};
local $old_frd = $ENV{'FOREIGN_ROOT_DIRECTORY'};
eval <<EOF;
package $pkg;
\$ENV{'FOREIGN_MODULE_NAME'} = '$_[0]';
\$ENV{'FOREIGN_ROOT_DIRECTORY'} = '$root_directory';
do "$mdir/$_[1]" || die \$@;
EOF
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
if ($@) { &error("require $_[0]/$_[1] failed : <pre>$@</pre>"); }
return 1;
}

=head2 foreign_call(module, function, [arg]*)

Call a function in another module

=cut
sub foreign_call
{
local $pkg = $_[0] ? $_[0] : "global";
$pkg =~ s/[^A-Za-z0-9]/_/g;
local @args = @_[2 .. @_-1];
$main::foreign_args = \@args;
local @rv = eval <<EOF;
package $pkg;
&$_[1](\@{\$main::foreign_args});
EOF
if ($@) { &error("$_[0]::$_[1] failed : $@"); }
return wantarray ? @rv : $rv[0];
}

=head2 foreign_config(module, [user-config])

Get the configuration from another module

=cut
sub foreign_config
{
local ($mod, $uc) = @_;
local %fconfig;
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
local ($mod, $configured) = @_;
if (defined($main::foreign_installed_cache{$mod,$configured})) {
	# Already cached..
	return $main::foreign_installed_cache{$mod,$configured};
	}
else {
	local $rv;
	if (!&foreign_check($mod)) {
		# Module is missing
		$rv = 0;
		}
	else {
		local $mdir = &module_root_directory($mod);
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

Returns 1 if some function is defined in another module

=cut
sub foreign_defined
{
local $pkg = $_[0];
$pkg =~ s/[^A-Za-z0-9]/_/g;
local $func = "${pkg}::$_[1]";
return defined(&$func);
}

=head2 get_system_hostname([short])

Returns the hostname of this system

=cut
sub get_system_hostname
{
local $m = int($_[0]);
if (!$main::get_system_hostname[$m]) {
	if ($gconfig{'os_type'} ne 'windows') {
		# Try some common Linux hostname files first
		if ($gconfig{'os_type'} eq 'redhat-linux') {
			local %nc;
			&read_env_file("/etc/sysconfig/network", \%nc);
			if ($nc{'HOSTNAME'}) {
				$main::get_system_hostname[$m] =$nc{'HOSTNAME'};
				return $nc{'HOSTNAME'};
				}
			}
		elsif ($gconfig{'os_type'} eq 'debian-linux') {
			local $hn = &read_file_contents("/etc/hostname");
			if ($hn) {
				$hn =~ s/\r|\n//g;
				$main::get_system_hostname[$m] = $hn;
				return $hn;
				}
			}
		elsif ($gconfig{'os_type'} eq 'open-linux') {
			local $hn = &read_file_contents("/etc/HOSTNAME");
			if ($hn) {
				$hn =~ s/\r|\n//g;
				$main::get_system_hostname[$m] = $hn;
				return $hn;
				}
			}
		elsif ($gconfig{'os_type'} eq 'solaris') {
			local $hn = &read_file_contents("/etc/nodename");
			if ($hn) {
				$hn =~ s/\r|\n//g;
				$main::get_system_hostname[$m] = $hn;
				return $hn;
				}
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
			local $flag;
			local $ex = &execute_command("hostname -f", undef, \$flag,
						     undef, 0, 1);
			chop($flag);
			if ($ex || $flag eq "") {
				# -f not supported! We have probably set the hostname
				# to just '-f'. Fix the problem (if we are root)
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
		local $out = `net name 2>&1`;
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

Returns the version of Webmin currently being run

=cut
sub get_webmin_version
{
if (!$get_webmin_version) {
	open(VERSION, "$root_directory/version") || return 0;
	($get_webmin_version = <VERSION>) =~ tr/\r|\n//d;
	close(VERSION);
	}
return $get_webmin_version;
}

=head2 get_module_acl([user], [module], [no-rbac], [no-default])

Returns a hash  containing access control options for the given user

=cut
sub get_module_acl
{
local %rv;
local $u = defined($_[0]) ? $_[0] : $base_remote_user;
local $m = defined($_[1]) ? $_[1] : $module_name;
local $mdir = &module_root_directory($m);
if (!$_[3]) {
	# Read default ACL first, to be overridden by per-user settings
	&read_file_cached("$mdir/defaultacl", \%rv);

	# If this isn't a master admin user, apply the negative permissions
	# so that he doesn't un-expectedly gain access to new features
	local %gacccess;
	&read_file_cached("$config_directory/$u.acl", \%gaccess);
	if ($gaccess{'negative'}) {
		&read_file_cached("$mdir/negativeacl", \%rv);
		}
	}
local %usersacl;
if (!$_[2] && &supports_rbac($m) && &use_rbac_module_acl($u, $m)) {
	# RBAC overrides exist for this user in this module
	local $rbac = &get_rbac_module_acl(
			defined($_[0]) ? $_[0] : $remote_user, $m);
	local $r;
	foreach $r (keys %$rbac) {
		$rv{$r} = $rbac->{$r};
		}
	}
elsif ($gconfig{"risk_$u"} && $m) {
	# ACL is defined by user's risk level
	local $rf = $gconfig{"risk_$u"}.'.risk';
	&read_file_cached("$mdir/$rf", \%rv);

	local $sf = $gconfig{"skill_$u"}.'.skill';
	&read_file_cached("$mdir/$sf", \%rv);
	}
elsif ($u ne '') {
	# Use normal Webmin ACL, if a user is set
	&read_file_cached("$config_directory/$m/$u.acl", \%rv);
	if ($remote_user ne $base_remote_user && !defined($_[0])) {
		&read_file_cached("$config_directory/$m/$remote_user.acl",\%rv);
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

=head2 get_group_module_acl(group, [module])

Returns the ACL for a Webmin group

=cut
sub get_group_module_acl
{
local %rv;
local $g = $_[0];
local $m = defined($_[1]) ? $_[1] : $module_name;
local $mdir = &module_root_directory($m);
&read_file_cached("$mdir/defaultacl", \%rv);
&read_file_cached("$config_directory/$m/$g.gacl", \%rv);
if (defined(&theme_get_module_acl)) {
	%rv = &theme_get_module_acl($g, $m, \%rv);
	}
return %rv;
}

=head2 save_module_acl(&acl, [user], [module])

Updates the acl hash for some user and module (or the current one)

=cut
sub save_module_acl
{
local $u = defined($_[1]) ? $_[1] : $base_remote_user;
local $m = defined($_[2]) ? $_[2] : $module_name;
if (&foreign_check("acl")) {
	# Check if this user is a member of a group, and if he gets the
	# module from a group. If so, update its ACL as well
	&foreign_require("acl", "acl-lib.pl");
	local ($g, $group);
	foreach $g (&acl::list_groups()) {
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
if (!-d "$config_directory/$m") {
	mkdir("$config_directory/$m", 0755);
	}
&write_file("$config_directory/$m/$u.acl", $_[0]);
}

=head2 save_group_module_acl(&acl, group, [module])

Updates the acl hash for some group and module (or the current one)

=cut
sub save_group_module_acl
{
local $g = $_[1];
local $m = defined($_[2]) ? $_[2] : $module_name;
if (&foreign_check("acl")) {
	# Check if this group is a member of a group, and if it gets the
	# module from a group. If so, update the parent ACL as well
	&foreign_require("acl", "acl-lib.pl");
	local ($pg, $group);
	foreach $pg (&acl::list_groups()) {
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
if (!-d "$config_directory/$m") {
	mkdir("$config_directory/$m", 0755);
	}
&write_file("$config_directory/$m/$g.gacl", $_[0]);
}

=head2 init_config

Sets the following variables
%config - Per-module configuration
%gconfig - Global configuration
$tb - Background for table headers
$cb - Background for table bodies
$scriptname - Base name of the current perl script
$module_name - The name of the current module
$module_config_directory - The config directory for this module
$module_config_file - The config file for this module
$webmin_logfile - The detailed logfile for webmin
$remote_user - The actual username used to login to webmin
$base_remote_user - The username whose permissions are in effect
$current_theme - The theme currently in use
$root_directory - The first root directory of this webmin install
@root_directories - All root directories for this webmin install

=cut
sub init_config
{
# Read the webmin global config file. This contains the OS type and version,
# OS specific configuration and global options such as proxy servers
$config_file = "$config_directory/config";
%gconfig = ( );
&read_file_cached($config_file, \%gconfig);
$null_file = $gconfig{'os_type'} eq 'windows' ? "NUL" : "/dev/null";
$path_separator = $gconfig{'os_type'} eq 'windows' ? ';' : ':';

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
local %miniserv;
if (&get_miniserv_config(\%miniserv)) {
	@root_directories = ( $miniserv{'root'} );
	for($i=0; defined($miniserv{"extraroot_$i"}); $i++) {
		push(@root_directories, $miniserv{"extraroot_$i"});
		}
	}

# Work out which module we are in, and read the per-module config file
$0 =~ s/\\/\//g;	# Force consistent path on Windows
if (defined($ENV{'FOREIGN_MODULE_NAME'})) {
	# In a foreign call - use the module name given
	$root_directory = $ENV{'FOREIGN_ROOT_DIRECTORY'};
	$module_name = $ENV{'FOREIGN_MODULE_NAME'};
	@root_directories = ( $root_directory ) if (!@root_directories);
	}
elsif ($ENV{'SCRIPT_NAME'}) {
	local $sn = $ENV{'SCRIPT_NAME'};
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
	local $r;
	local $rok = 0;
	foreach $r (@root_directories) {
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

# Set the umask based on config
if ($gconfig{'umask'} && !$main::umask_already++) {
	umask(oct($gconfig{'umask'}));
	}

# If this is a cron job or other background task, set the nice level
if (!$main::nice_already && $main::webmin_script_type eq 'cron') {
	# Set nice level
	if ($gconfig{'nice'}) {
		eval 'use POSIX; POSIX::nice($gconfig{\'nice\'});';
		}

	# Set IO scheduling class and priority
	if ($gconfig{'sclass'} ne '' || $gconfig{'sprio'} ne '') {
		local $cmd = "ionice";
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
local $u = $ENV{'BASE_REMOTE_USER'} ? $ENV{'BASE_REMOTE_USER'}
				    : $ENV{'REMOTE_USER'};
$base_remote_user = $u;
$remote_user = $ENV{'REMOTE_USER'};

if ($module_name) {
	# Find and load the configuration file for this module
	local (@ruinfo, $rgroup);
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

	# Fix up windows-specific substitutions in values
	foreach my $k (keys %config) {
		if ($config{$k} =~ /\$\{systemroot\}/) {
			my $root = &get_windows_root();
			$config{$k} =~ s/\$\{systemroot\}/$root/g;
			}
		}
	}

# If debugging is enabled, open the debug log
if ($gconfig{'debug_enabled'} && !$main::opened_debug_log++) {
	local $dlog = $gconfig{'debug_file'} || $main::default_debug_log_file;
	if ($gconfig{'debug_size'}) {
		local @st = stat($dlog);
		if ($st[7] > $gconfig{'debug_size'}) {
			rename($dlog, $dlog.".0");
			}
		}
	open(main::DEBUGLOG, ">>$dlog");
	$main::opened_debug_log = 1;

	if ($gconfig{'debug_what_start'}) {
		local $script_name = $0 =~ /([^\/]+)$/ ? $1 : '-';
		$main::debug_log_start_time = time();
		&webmin_debug_log("START", "script=$script_name");
		$main::debug_log_start_module = $module_name;
		}
	}

# Record the initial module
$main::initial_module_name ||= $module_name;

# Set some useful variables
local $current_themes;
$current_themes = $ENV{'MOBILE_DEVICE'} && defined($gconfig{'mobile_theme'}) ?
		    $gconfig{'mobile_theme'} :
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
	local %onetconfig;
	&read_file_cached("$troot/config", \%onetconfig);
	&read_file_cached("$troot/config", \%tconfig);
	push(@theme_configs, \%onetconfig);
	}
$tb = defined($tconfig{'cs_header'}) ? "bgcolor=#$tconfig{'cs_header'}" :
      defined($gconfig{'cs_header'}) ? "bgcolor=#$gconfig{'cs_header'}" :
				       "bgcolor=#9999ff";
$cb = defined($tconfig{'cs_table'}) ? "bgcolor=#$tconfig{'cs_table'}" :
      defined($gconfig{'cs_table'}) ? "bgcolor=#$gconfig{'cs_table'}" :
				      "bgcolor=#cccccc";
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
local @langs = &list_languages();
local ($l, $a, $accepted_lang);
if ($gconfig{'acceptlang'}) {
	foreach $a (split(/,/, $ENV{'HTTP_ACCEPT_LANGUAGE'})) {
		local ($al) = grep { $_->{'lang'} eq $a } @langs;
		if ($al) {
			$accepted_lang = $al->{'lang'};
			last;
			}
		}
	}
$current_lang = $force_lang ? $force_lang :
    $accepted_lang ? $accepted_lang :
    $gconfig{"lang_$remote_user"} ? $gconfig{"lang_$remote_user"} :
    $gconfig{"lang_$base_remote_user"} ? $gconfig{"lang_$base_remote_user"} :
    $gconfig{"lang"} ? $gconfig{"lang"} : $default_lang;
foreach $l (@langs) {
	$current_lang_info = $l if ($l->{'lang'} eq $current_lang);
	}
@lang_order_list = &unique($default_lang,
		     	   split(/:/, $current_lang_info->{'fallback'}),
			   $current_lang);
%text = &load_language($module_name);
%text || &error("Failed to determine Webmin root from SERVER_ROOT, SCRIPT_FILENAME or the full command line");

# Get the %module_info for this module
if ($module_name) {
	local ($mi) = grep { $_->{'dir'} eq $module_name }
			 &get_all_module_infos(2);
	%module_info = %$mi;
	$module_root_directory = &module_root_directory($module_name);
	}

if ($module_name && !$main::no_acl_check &&
    !defined($ENV{'FOREIGN_MODULE_NAME'})) {
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
local @referers = split(/\s+/, $gconfig{'referers'});
local $referer_site;
if ($ENV{'HTTP_REFERER'} =~/^(http|https|ftp):\/\/([^:\/]+:[^@\/]+@)?([^\/:@]+)/) {
	$referer_site = $3;
	}
local $http_host = $ENV{'HTTP_HOST'};
$http_host =~ s/:\d+$//;
if ($0 &&
    ($ENV{'SCRIPT_NAME'} !~ /^\/(index.cgi)?$/ || $unsafe_index_cgi) &&
    ($ENV{'SCRIPT_NAME'} !~ /^\/([a-z0-9\_\-]+)\/(index.cgi)?$/i ||
     $unsafe_index_cgi) &&
    $0 !~ /session_login\.cgi$/ && !$gconfig{'referer'} &&
    $ENV{'MINISERV_CONFIG'} && !$main::no_referers_check &&
    $ENV{'HTTP_USER_AGENT'} !~ /^Webmin/i &&
    ($referer_site && $referer_site ne $http_host &&
     &indexof($referer_site, @referers) < 0 ||
    !$referer_site && $gconfig{'referers_none'}) && !$trust_unknown_referers) {
	# Looks like a link from elsewhere .. show an error
	&header($text{'referer_title'}, "", undef, 0, 1, 1);

	$prot = lc($ENV{'HTTPS'}) eq 'on' ? "https" : "http";
	local $url = "<tt>".&html_escape("$prot://$ENV{'HTTP_HOST'}$ENV{'REQUEST_URI'}")."</tt>";
	if ($referer_site) {
		# From a known host
		print &text('referer_warn',
		     "<tt>".&html_escape($ENV{'HTTP_REFERER'})."</tt>", $url);
		print "<p>\n";
		print &text('referer_fix1', &html_escape($http_host)),"<p>\n";
		print &text('referer_fix2', &html_escape($http_host)),"<p>\n";
		}
	else {
		# No referer info given
		print &text('referer_warn_unknown', $url),"<p>\n";
		print &text('referer_fix1u'),"<p>\n";
		print &text('referer_fix2u'),"<p>\n";
		}
	print "<p>\n";

	&footer("/", $text{'index'});
	exit;
	}
$main::no_referers_check++;
$main::completed_referers_check++;

# Call theme post-init
if (defined(&theme_post_init_config)) {
	&theme_post_init_config(@_);
	}

# Record that we have done the calling library in this package
local ($pkg, $lib) = caller();
$lib =~ s/^.*\///;
$main::done_foreign_require{$pkg,$lib} = 1;

# If a licence checking is enabled, do it now
if ($gconfig{'licence_module'} && !$main::done_licence_module_check &&
    &foreign_check($gconfig{'licence_module'}) &&
    -r "$root_directory/$gconfig{'licence_module'}/licence_check.pl") {
	local $oldpwd = &get_current_dir();
	$main::done_licence_module_check++;
	$main::licence_module = $gconfig{'licence_module'};
	&foreign_require($main::licence_module, "licence_check.pl");
	($main::licence_status, $main::licence_message) =
		&foreign_call($main::licence_module, "check_licence");
	chdir($oldpwd);
	}

return 1;
}

$default_lang = "en";

=head2 load_language(module, [directory])

Returns a hashtable mapping text codes to strings in the appropriate language

=cut
sub load_language
{
local %text;
local $root = $root_directory;
local $ol = $gconfig{'overlang'};
local $o;
local ($dir) = ($_[1] || "lang");

# Read global lang files
foreach $o (@lang_order_list) {
	local $ok = &read_file_cached("$root/$dir/$o", \%text);
	return () if (!$ok && $o eq $default_lang);
	}
if ($ol) {
	foreach $o (@lang_order_list) {
		&read_file_cached("$root/$ol/$o", \%text);
		}
	}
&read_file_cached("$config_directory/custom-lang", \%text);

if ($_[0]) {
	# Read module's lang files
	local $mdir = &module_root_directory($_[0]);
	foreach $o (@lang_order_list) {
		&read_file_cached("$mdir/$dir/$o", \%text);
		}
	if ($ol) {
		foreach $o (@lang_order_list) {
			&read_file_cached("$mdir/$ol/$o", \%text);
			}
		}
	&read_file_cached("$config_directory/$_[0]/custom-lang", \%text);
	}
foreach $k (keys %text) {
	$text{$k} =~ s/\$(\{([^\}]+)\}|([A-Za-z0-9\.\-\_]+))/text_subs($2 || $3,\%text)/ge;
	}

if (defined(&theme_load_language)) {
	&theme_load_language(\%text, $_[0]);
	}
return %text;
}

sub text_subs
{
if (substr($_[0], 0, 8) eq "include:") {
	local $_;
	local $rv;
	open(INCLUDE, substr($_[0], 8));
	while(<INCLUDE>) {
		$rv .= $_;
		}
	close(INCLUDE);
	return $rv;
	}
else {
	local $t = $_[1]->{$_[0]};
	return defined($t) ? $t : '$'.$_[0];
	}
}

=head2 text(message, [substitute]+)

Returns a translated message from %text, but with $1, $2, etc.. replaced with the
substitute parameters.

=cut
sub text
{
local $rv = $text{$_[0]};
local $i;
for($i=1; $i<@_; $i++) {
	$rv =~ s/\$$i/$_[$i]/g;
	}
return $rv;
}

=head2 terror(text params)

MISSING DOCUMENTATION

=cut
sub terror
{
&error(&text(@_));
}

=head2 encode_base64(string)

Encodes a string into base64 format

=cut
sub encode_base64
{
    local $res;
    pos($_[0]) = 0;                          # ensure start at the beginning
    while ($_[0] =~ /(.{1,57})/gs) {
        $res .= substr(pack('u57', $1), 1)."\n";
        chop($res);
    }
    $res =~ tr|\` -_|AA-Za-z0-9+/|;
    local $padding = (3 - length($_[0]) % 3) % 3;
    $res =~ s/.{$padding}$/'=' x $padding/e if ($padding);
    return $res;
}

=head2 decode_base64(string)

Converts a base64 string into plain text

=cut
sub decode_base64
{
    local $str = $_[0];
    local $res;
 
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

=head2 get_module_info(module, [noclone], [forcache])

Returns a hash containg a module name, desc and os_support

=cut
sub get_module_info
{
return () if ($_[0] =~ /^\./);
local (%rv, $clone, $o);
local $mdir = &module_root_directory($_[0]);
&read_file_cached("$mdir/module.info", \%rv) || return ();
$clone = -l $mdir;
foreach $o (@lang_order_list) {
	$rv{"desc"} = $rv{"desc_$o"} if ($rv{"desc_$o"});
	$rv{"longdesc"} = $rv{"longdesc_$o"} if ($rv{"longdesc_$o"});
	}
if ($clone && !$_[1] && $config_directory) {
	$rv{'clone'} = $rv{'desc'};
	&read_file("$config_directory/$_[0]/clone", \%rv);
	}
$rv{'dir'} = $_[0];
local %module_categories;
&read_file_cached("$config_directory/webmin.cats", \%module_categories);
local $pn = &get_product_name();
if (defined($rv{'category_'.$pn})) {
	# Can override category for webmin/usermin
	$rv{'category'} = $rv{'category_'.$pn};
	}
$rv{'realcategory'} = $rv{'category'};
$rv{'category'} = $module_categories{$_[0]}
	if (defined($module_categories{$_[0]}));

# Apply description overrides
$rv{'realdesc'} = $rv{'desc'};
local %descs;
&read_file_cached("$config_directory/webmin.descs", \%descs);
if ($descs{$_[0]." ".$current_lang}) {
	$rv{'desc'} = $descs{$_[0]." ".$current_lang};
	}
elsif ($descs{$_[0]}) {
	$rv{'desc'} = $descs{$_[0]};
	}

if (!$_[2]) {
	# Apply per-user description overridde
	local %gaccess = &get_module_acl(undef, "");
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

Returns a vector contains the information on all modules in this webmin
install, including clones.
Cache mode 0 = read and write, 1 = don't read or write, 2 = read only

=cut
sub get_all_module_infos
{
local (%cache, $k, $m, $r, @rv);

# Is the cache out of date? (ie. have any of the root's changed?)
local $cache_file = "$config_directory/module.infos.cache";
local $changed = 0;
if (&read_file_cached($cache_file, \%cache)) {
	foreach $r (@root_directories) {
		local @st = stat($r);
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
	local %mods;
	foreach $k (keys %cache) {
		if ($k =~ /^(\S+) (\S+)$/) {
			$mods{$1}->{$2} = $cache{$k};
			}
		}
	@rv = map { $mods{$_} } (keys %mods) if (%mods);
	}
else {
	# Need to rebuild cache
	%cache = ( );
	foreach $r (@root_directories) {
		opendir(DIR, $r);
		foreach $m (readdir(DIR)) {
			next if ($m =~ /^(config-|\.)/ || $m =~ /\.(cgi|pl)$/);
			local %minfo = &get_module_info($m, 0, 1);
			next if (!%minfo || !$minfo{'dir'});
			push(@rv, \%minfo);
			foreach $k (keys %minfo) {
				$cache{"${m} ${k}"} = $minfo{$k};
				}
			}
		closedir(DIR);
		local @st = stat($r);
		$cache{'mtime_'.$r} = $st[9];
		}
	$cache{'lang'} = $current_lang;
	&write_file($cache_file, \%cache) if (!$_[0] && $< == 0 && $> == 0);
	}

# Override descriptions for modules for current user
local %gaccess = &get_module_acl(undef, "");
foreach $m (@rv) {
	if ($gaccess{"desc_".$m->{'dir'}}) {
		$m->{'desc'} = $gaccess{"desc_".$m->{'dir'}};
		}
	}

# Apply installed flags
local %installed;
&read_file_cached("$config_directory/installed.cache", \%installed);
foreach $m (@rv) {
	$m->{'installed'} = $installed{$m->{'dir'}};
	}

return @rv;
}

=head2 get_theme_info(theme)

Returns a hash containing a theme's details

=cut
sub get_theme_info
{
return () if ($_[0] =~ /^\./);
local (%rv, $o);
local $tdir = &module_root_directory($_[0]);
&read_file("$tdir/theme.info", \%rv) || return ();
foreach $o (@lang_order_list) {
	$rv{"desc"} = $rv{"desc_$o"} if ($rv{"desc_$o"});
	}
$rv{"dir"} = $_[0];
return %rv;
}

=head2 list_languages

Returns an array of supported languages

=cut
sub list_languages
{
if (!@main::list_languages_cache) {
	local ($o, $_);
	open(LANG, "$root_directory/lang_list.txt");
	while(<LANG>) {
		if (/^(\S+)\s+(.*)/) {
			local $l = { 'desc' => $2 };
			foreach $o (split(/,/, $1)) {
				if ($o =~ /^([^=]+)=(.*)$/) {
					$l->{$1} = $2;
					}
				}
			$l->{'index'} = scalar(@rv);
			push(@main::list_languages_cache, $l);
			}
		}
	close(LANG);
	@main::list_languages_cache = sort { $a->{'desc'} cmp $b->{'desc'} }
				     @main::list_languages_cache;
	}
return @main::list_languages_cache;
}

=head2 read_env_file(file, &array)

MISSING DOCUMENTATION

=cut
sub read_env_file
{
local $_;
&open_readfile(FILE, $_[0]) || return 0;
while(<FILE>) {
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

=head2 write_env_file(file, &array, export)

Writes out a hash to a file in name='value' format, suitable for use in a sh
script.

=cut
sub write_env_file
{
local $k;
local $exp = $_[2] ? "export " : "";
&open_tempfile(FILE, ">$_[0]");
foreach $k (keys %{$_[1]}) {
	local $v = $_[1]->{$k};
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
until it is freed. This version uses a .lock file, which is not very reliable.

=cut
sub lock_file
{
local $realfile = &translate_filename($_[0]);
return 0 if (!$_[0] || defined($main::locked_file_list{$realfile}));
local $no_lock = !&can_lock_file($realfile);
local $lock_tries_count = 0;
while(1) {
	local $pid;
	if (!$no_lock && open(LOCKING, "$realfile.lock")) {
		$pid = <LOCKING>;
		$pid = int($pid);
		close(LOCKING);
		}
	if ($no_lock || !$pid || !kill(0, $pid) || $pid == $$) {
		# Got the lock!
		if (!$no_lock) {
			# Create the .lock file
			open(LOCKING, ">$realfile.lock") || return 0;
			local $lck = eval "flock(LOCKING, 2+4)";
			if (!$lck && !$@) {
				# Lock of lock file failed! Wait till later
				goto tryagain;
				}
			print LOCKING $$,"\n";
			eval "flock(LOCKING, 8)";
			close(LOCKING);
			}
		$main::locked_file_list{$realfile} = int($_[1]);
		push(@main::temporary_files, "$realfile.lock");
		if (($gconfig{'logfiles'} || $gconfig{'logfullfiles'}) &&
		    !$_[1]) {
			# Grab a copy of this file for later diffing
			local $lnk;
			$main::locked_file_data{$realfile} = undef;
			if (-d $realfile) {
				$main::locked_file_type{$realfile} = 1;
				$main::locked_file_data{$realfile} = '';
				}
			elsif (!$_[2] && ($lnk = readlink($realfile))) {
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
		&error(&text('elock_tries', "<tt>$realfile</tt>", 5));
		}
	}
return 1;
}

=head2 unlock_file(filename)

Release a lock on a file. When unlocking a file that was locked in
read mode, optionally save the update in RCS

=cut
sub unlock_file
{
local $realfile = &translate_filename($_[0]);
return if (!$_[0] || !defined($main::locked_file_list{$realfile}));
unlink("$realfile.lock") if (&can_lock_file($realfile));
delete($main::locked_file_list{$realfile});
if (exists($main::locked_file_data{$realfile})) {
	# Diff the new file with the old
	stat($realfile);
	local $lnk = readlink($realfile);
	local $type = -d _ ? 1 : $lnk ? 2 : 0;
	local $oldtype = $main::locked_file_type{$realfile};
	local $new = !defined($main::locked_file_data{$realfile});
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
		local ($diff, $delete_file);
		local $type = "modify";
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

Returns 1 if some file is currently locked

=cut
sub test_lock
{
local $realfile = &translate_filename($_[0]);
return 0 if (!$_[0]);
return 1 if (defined($main::locked_file_list{$realfile}));
return 0 if (!&can_lock_file($realfile));
local $pid;
if (open(LOCKING, "$realfile.lock")) {
	$pid = <LOCKING>;
	$pid = int($pid);
	close(LOCKING);
	}
return $pid && kill(0, $pid);
}

=head2 unlock_all_files

Unlocks all files locked by this program

=cut
sub unlock_all_files
{
foreach $f (keys %main::locked_file_list) {
	&unlock_file($f);
	}
}

=head2 can_lock_file(file)

Returns 1 if some file should be locked

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
	local ($d, $match);
	foreach $d (split(/\t+/, $gconfig{'lockdirs'})) {
		if (&same_file($d, $_[0]) ||
		    &is_under_directory($d, $_[0])) {
			$match = 1;
			}
		}
	return $gconfig{'lockmode'} == 2 ? $match : !$match;
	}
}

=head2 webmin_log(action, type, object, &params, [module], [host, script-on-host, client-ip])

Log some action taken by a user

=cut
sub webmin_log
{
return if (!$gconfig{'log'} || &is_readonly_mode());
local $m = $_[4] ? $_[4] : $module_name;

if ($gconfig{'logclear'}) {
	# check if it is time to clear the log
	local @st = stat("$webmin_logfile.time");
	local $write_logtime = 0;
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
	else { $write_logtime = 1; }
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

    for my $dir ($basedir/$type/$action, $basedir/$type, $basedir) {
	if (-d $dir) {
	    my ($file);
	    opendir(DIR, $dir) or die "Can't open $dir: $!";
	    while (defined($file = readdir(DIR))) {
		next if ($file =~ /^\.\.?$/); # skip '.' and '..'
		if (-x "$dir/$file") {
		    # Call a script notifying it of the action
		    local %OLDENV = %ENV;
		    $ENV{'ACTION_MODULE'} = $module_name;
		    $ENV{'ACTION_ACTION'} = $_[0];
		    $ENV{'ACTION_TYPE'} = $_[1];
		    $ENV{'ACTION_OBJECT'} = $_[2];
		    $ENV{'ACTION_SCRIPT'} = $script_name;
		    local $p;
		    foreach $p (keys %param) {
			    $ENV{'ACTION_PARAM_'.uc($p)} = $param{$p};
			    }
		    system("$dir/$file", @_, "<$null_file", ">$null_file", "2>&1");
		    %ENV = %OLDENV;
		    }
		}
	    }
	}
    }

# should logging be done at all?
return if ($gconfig{'logusers'} && &indexof($base_remote_user,
	   split(/\s+/, $gconfig{'logusers'})) < 0);
return if ($gconfig{'logmodules'} && &indexof($m,
	   split(/\s+/, $gconfig{'logmodules'})) < 0);

# log the action
local $now = time();
local @tm = localtime($now);
local $script_name = $0 =~ /([^\/]+)$/ ? $1 : '-';
local $id = sprintf "%d.%d.%d",
		$now, $$, $main::action_id_count;
$main::action_id_count++;
local $line = sprintf "%s [%2.2d/%s/%4.4d %2.2d:%2.2d:%2.2d] %s %s %s %s %s \"%s\" \"%s\" \"%s\"",
	$id, $tm[3], $text{"smonth_".($tm[4]+1)}, $tm[5]+1900,
	$tm[2], $tm[1], $tm[0],
	$remote_user || '-',
	$main::session_id || '-',
	$_[7] || $ENV{'REMOTE_HOST'} || '-',
	$m, $_[5] ? "$_[5]:$_[6]" : $script_name,
	$_[0], $_[1] ne '' ? $_[1] : '-', $_[2] ne '' ? $_[2] : '-';
local %param;
foreach $k (sort { $a cmp $b } keys %{$_[3]}) {
	local $v = $_[3]->{$k};
	local @pv;
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

if ($gconfig{'logfiles'}) {
	# Find and record the changes made to any locked files, or commands run
	local $i = 0;
	mkdir("$ENV{'WEBMIN_VAR'}/diffs", 0700);
	foreach $d (@main::locked_file_diff) {
		mkdir("$ENV{'WEBMIN_VAR'}/diffs/$id", 0700);
		open(DIFFLOG, ">$ENV{'WEBMIN_VAR'}/diffs/$id/$i");
		print DIFFLOG "$d->{'type'} $d->{'object'}\n";
		print DIFFLOG $d->{'data'};
		close(DIFFLOG);
		if ($d->{'input'}) {
			open(DIFFLOG, ">$ENV{'WEBMIN_VAR'}/diffs/$id/$i.input");
			print DIFFLOG $d->{'input'};
			close(DIFFLOG);
			}
		if ($gconfig{'logperms'}) {
			chmod(oct($gconfig{'logperms'}),
			      "$ENV{'WEBMIN_VAR'}/diffs/$id/$i",
			      "$ENV{'WEBMIN_VAR'}/diffs/$id/$i.input");
			}
		$i++;
		}
	@main::locked_file_diff = undef;
	}
if ($gconfig{'logfullfiles'}) {
	# Save the original contents of any modified files
	local $i = 0;
	mkdir("$ENV{'WEBMIN_VAR'}/files", 0700);
	local $f;
	foreach $f (keys %main::orig_file_data) {
		mkdir("$ENV{'WEBMIN_VAR'}/files/$id", 0700);
		open(ORIGLOG, ">$ENV{'WEBMIN_VAR'}/files/$id/$i");
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
			      "$ENV{'WEBMIN_VAR'}/files/$id.$i");
			}
		$i++;
		}
	%main::orig_file_data = undef;
	%main::orig_file_type = undef;
	}

# Log to syslog too
if ($gconfig{'logsyslog'}) {
	eval 'use Sys::Syslog qw(:DEFAULT setlogsock);
	      openlog(&get_product_name(), "cons,pid,ndelay", "daemon");
	      setlogsock("inet");';
	if (!$@) {
		# Syslog module is installed .. try to convert to a
		# human-readable form
		local $msg;
		if (-r "$module_root_directory/log_parser.pl") {
			do "$module_root_directory/log_parser.pl";
			local %params;
			foreach my $k (keys %{$_[3]}) {
				my $v = $_[3]->{$k};
				if (ref($v) eq 'ARRAY') {
					$params{$k} = join("\0", @$v);
					}
				else {
					$params{$k} = $v;
					}
				}
			$msg = &parse_webmin_log($remote_user, $script_name,
						 $_[0], $_[1], $_[2], \%params);
			$msg =~ s/<[^>]*>//g;	# Remove tags
			}
		elsif ($_[0] eq "_config_") {
			local %wtext = &load_language("webminlog");
			$msg = $wtext{'search_config'};
			}
		else {
			$msg = "$_[0] $_[1] $_[2]";
			}
		local %info = $m eq $module_name ? %module_info
						 : &get_module_info($m);
		eval { syslog("info", "%s", "[$info{'desc'}] $msg"); };
		}
	}
}

=head2 additional_log(type, object, data, [input])

Records additional log data for an upcoming call to webmin_log, such
as command that was run or SQL that was executed.

=cut
sub additional_log
{
if ($gconfig{'logfiles'}) {
	push(@main::locked_file_diff,
	     { 'type' => $_[0], 'object' => $_[1], 'data' => $_[2],
	       'input' => $_[3] } );
	}
}

=head2 webmin_debug_log(type, message)

Write something to the Webmin debug log

=cut
sub webmin_debug_log
{
local ($type, $msg) = @_;
return 0 if (!$main::opened_debug_log);
return 0 if ($gconfig{'debug_no'.$main::webmin_script_type});
local $now = time();
local @tm = localtime($now);
local $line = sprintf
	"%s [%2.2d/%s/%4.4d %2.2d:%2.2d:%2.2d] %s %s %s %s \"%s\"",
        $$, $tm[3], $text{"smonth_".($tm[4]+1)}, $tm[5]+1900,
        $tm[2], $tm[1], $tm[0],
	$remote_user || "-",
	$ENV{'REMOTE_HOST'} || "-",
	$module_name || "-",
	$type,
	$msg;
seek(main::DEBUGLOG, 0, 2);
print main::DEBUGLOG $line."\n";
return 1;
}

=head2 system_logged(command)

Just calls the system() function, but also logs the command

=cut
sub system_logged
{
if (&is_readonly_mode()) {
	print STDERR "Vetoing command $_[0]\n";
	return 0;
	}
local @realcmd = ( &translate_command($_[0]), @_[1..$#_] );
local $cmd = join(" ", @realcmd);
local $and;
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

Executes a command and returns the output (like `cmd`), but also logs it

=cut
sub backquote_logged
{
if (&is_readonly_mode()) {
	$? = 0;
	print STDERR "Vetoing command $_[0]\n";
	return undef;
	}
local $realcmd = &translate_command($_[0]);
local $cmd = $realcmd;
local $and;
if ($cmd =~ s/(\s*&\s*)$//) {
	$and = $1;
	}
while($cmd =~ s/(\d*)(<|>)((\/(tmp\/.webmin|dev)\S+)|&\d+)\s*$//) { }
$cmd =~ s/^\((.*)\)\s*$/$1/;
$cmd .= $and;
&additional_log('exec', undef, $cmd);
&webmin_debug_log('CMD', "cmd=$cmd") if ($gconfig{'debug_what_cmd'});
return `$realcmd`;
}

=head2 backquote_with_timeout(command, timeout, safe?, [maxlines])

Runs some command, waiting at most the given number of seconds for it to
complete, and returns the output

=cut
sub backquote_with_timeout
{
local $realcmd = &translate_command($_[0]);
&webmin_debug_log('CMD', "cmd=$realcmd timeout=$_[1]")
	if ($gconfig{'debug_what_cmd'});
local $out;
local $pid = &open_execute_command(OUT, "($realcmd) <$null_file", 1, $_[2]);
local $start = time();
local $timed_out = 0;
local $linecount = 0;
while(1) {
	local $elapsed = time() - $start;
	last if ($elapsed > $_[1]);
	local $rmask;
	vec($rmask, fileno(OUT), 1) = 1;
	local $sel = select($rmask, undef, undef, $_[1] - $elapsed);
	last if (!$sel || $sel < 0);
	local $line = <OUT>;
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

Executes a command and returns the output (like `cmd`), subject to
command translation

=cut
sub backquote_command
{
if (&is_readonly_mode() && !$_[1]) {
	print STDERR "Vetoing command $_[0]\n";
	$? = 0;
	return undef;
	}
local $realcmd = &translate_command($_[0]);
&webmin_debug_log('CMD', "cmd=$realcmd") if ($gconfig{'debug_what_cmd'});
return `$realcmd`;
}

=head2 kill_logged(signal, pid, ...)

MISSING DOCUMENTATION

=cut
sub kill_logged
{
return scalar(@_)-1 if (&is_readonly_mode());
&webmin_debug_log('KILL', "signal=$_[0] pids=".join(" ", @_[1..@_-1]))
	if ($gconfig{'debug_what_procs'});
&additional_log('kill', $_[0], join(" ", @_[1..@_-1])) if (@_ > 1);
if ($gconfig{'os_type'} eq 'windows') {
	# Emulate some kills with process.exe
	local $arg = $_[0] eq "KILL" ? "-k" :
		     $_[0] eq "TERM" ? "-q" :
		     $_[0] eq "STOP" ? "-s" :
		     $_[0] eq "CONT" ? "-r" : undef;
	local $ok = 0;
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

Re-names a file and logs it, if allowed

=cut
sub rename_logged
{
&additional_log('rename', $_[0], $_[1]) if ($_[0] ne $_[1]);
return &rename_file($_[0], $_[1]);
}

=head2 rename_file(old, new)

Renames a file, unless in read-only mode

=cut
sub rename_file
{
if (&is_readonly_mode()) {
	print STDERR "Vetoing rename from $_[0] to $_[1]\n";
	return 1;
	}
local $src = &translate_filename($_[0]);
local $dst = &translate_filename($_[1]);
&webmin_debug_log('RENAME', "src=$src dst=$dst")
	if ($gconfig{'debug_what_ops'});
local $ok = rename($src, $dst);
if (!$ok && $! !~ /permission/i) {
	# Try the mv command, in case this is a cross-filesystem rename
	if ($gconfig{'os_type'} eq 'windows') {
		# Need to use rename
		local $out = &backquote_command("rename ".quotemeta($_[0])." ".quotemeta($_[1])." 2>&1");
		$ok = !$?;
		$! = $out if (!$ok);
		}
	else {
		# Can use mv
		local $out = &backquote_command("mv ".quotemeta($_[0])." ".quotemeta($_[1])." 2>&1");
		$ok = !$?;
		$! = $out if (!$ok);
		}
	}
return $ok;
}

=head2 symlink_logged(src, dest)

Create a symlink, and logs it

=cut
sub symlink_logged
{
&lock_file($_[1]);
local $rv = &symlink_file($_[0], $_[1]);
&unlock_file($_[1]);
return $rv;
}

=head2 symlink_file(src, dest)

Creates a soft link, unless in read-only mode

=cut
sub symlink_file
{
if (&is_readonly_mode()) {
	print STDERR "Vetoing symlink from $_[0] to $_[1]\n";
	return 1;
	}
local $src = &translate_filename($_[0]);
local $dst = &translate_filename($_[1]);
&webmin_debug_log('SYMLINK', "src=$src dst=$dst")
	if ($gconfig{'debug_what_ops'});
return symlink($src, $dst);
}

=head2 link_file(src, dest)

Creates a hard link, unless in read-only mode. The existing new link
will be deleted if necessary.

=cut
sub link_file
{
if (&is_readonly_mode()) {
	print STDERR "Vetoing link from $_[0] to $_[1]\n";
	return 1;
	}
local $src = &translate_filename($_[0]);
local $dst = &translate_filename($_[1]);
&webmin_debug_log('LINK', "src=$src dst=$dst")
	if ($gconfig{'debug_what_ops'});
unlink($dst);			# make sure link works
return link($src, $dst);
}

=head2 make_dir(dir, perms, recursive)

Creates a directory, unless in read-only mode

=cut
sub make_dir
{
local ($dir, $perms, $recur) = @_;
if (&is_readonly_mode()) {
	print STDERR "Vetoing directory $dir\n";
	return 1;
	}
$dir = &translate_filename($dir);
local $exists = -d $dir ? 1 : 0;
return 1 if ($exists && $recur);	# already exists
&webmin_debug_log('MKDIR', $dir) if ($gconfig{'debug_what_ops'});
local $rv = mkdir($dir, $perms);
if (!$rv && $recur) {
	# Failed .. try mkdir -p
	local $param = $gconfig{'os_type'} eq 'windows' ? "" : "-p";
	local $ex = &execute_command("mkdir $param ".&quote_path($dir));
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

Sets the user, group and permissions on some files

=cut
sub set_ownership_permissions
{
local ($user, $group, $perms, @files) = @_;
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
local $rv = 1;
if (defined($user)) {
	local $uid = $user !~ /^\d+$/ ? getpwnam($user) : $user;
	local $gid;
	if (defined($group)) {
		$gid = $group !~ /^\d+$/ ? getgrnam($group) : $group;
		}
	else {
		local @uinfo = getpwuid($uid);
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

MISSING DOCUMENTATION

=cut
sub unlink_logged
{
local %locked;
foreach my $f (@_) {
	if (!&test_lock($f)) {
		&lock_file($f);
		$locked{$f} = 1;
		}
	}
local @rv = &unlink_file(@_);
foreach my $f (@_) {
	if ($locked{$f}) {
		&unlock_file($f);
		}
	}
return wantarray ? @rv : $rv[0];
}

=head2 unlink_file(file, ...)

Deletes some files or directories, if allowed

=cut
sub unlink_file
{
return 1 if (&is_readonly_mode());
my $rv = 1;
my $err;
foreach my $f (@_) {
	my $realf = &translate_filename($f);
	&webmin_debug_log('UNLINK', $realf) if ($gconfig{'debug_what_ops'});
	if (-d $realf) {
		if (!rmdir($realf)) {
			if ($gconfig{'os_type'} eq 'windows') {
				# Call del and rmdir commands
				my $qm = $realf;
				$qm =~ s/\//\\/g;
				local $out = `del /q "$qm" 2>&1`;
				if (!$?) {
					$out = `rmdir "$qm" 2>&1`;
					}
				}
			else {
				# Use rm command
				my $qm = quotemeta($realf);
				local $out = `rm -rf $qm 2>&1`;
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

=head2 copy_source_dest(source, dest)

Copy some file or directory to a new location. Returns 1 on success, or 0
on failure - also sets $!

=cut
sub copy_source_dest
{
return (1, undef) if (&is_readonly_mode());
local ($src, $dst) = @_;
local $ok = 1;
local ($err, $out);
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
	local @st = stat($src);
	unlink($dst);
	mkdir($dst, 0755);
	&set_ownership_permissions($st[4], $st[5], $st[2], $dst);
	$out = &backquote_logged("(cd ".quotemeta($src)." ; tar cf - . | (cd ".quotemeta($dst)." ; tar xf -)) 2>&1");
	if ($?) {
		$ok = 0;
		$err = $out;
		}
	}
else {
	# Can just copy with cp
	local $out = &backquote_logged("cp -p ".quotemeta($src).
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
port and PID. For a server name, it will include the hostname and PID.

=cut
sub remote_session_name
{
return ref($_[0]) && $_[0]->{'host'} && $_[0]->{'port'} ?
		"$_[0]->{'host'}:$_[0]->{'port'}.$$" :
       $_[0] eq "" || ref($_[0]) && $_[0]->{'id'} == 0 ? "" :
       ref($_[0]) ? "" : "$_[0].$$";
}

=head2 remote_foreign_require(server, module, file)

Connect to rpc.cgi on a remote webmin server and have it open a session
to a process that will actually do the require and run functions.

=cut
sub remote_foreign_require
{
local $call = { 'action' => 'require',
		'module' => $_[1],
		'file' => $_[2] };
local $sn = &remote_session_name($_[0]);
if ($remote_session{$sn}) {
	$call->{'session'} = $remote_session{$sn};
	}
else {
	$call->{'newsession'} = 1;
	}
local $rv = &remote_rpc_call($_[0], $call);
if ($rv->{'session'}) {
	$remote_session{$sn} = $rv->{'session'};
	$remote_session_server{$sn} = $_[0];
	}
}

=head2 remote_foreign_call(server, module, function, [arg]*)

Call a function on a remote server. Must have been setup first with
remote_foreign_require for the same server and module

=cut
sub remote_foreign_call
{
return undef if (&is_readonly_mode());
local $sn = &remote_session_name($_[0]);
return &remote_rpc_call($_[0], { 'action' => 'call',
				 'module' => $_[1],
				 'func' => $_[2],
				 'session' => $remote_session{$sn},
				 'args' => [ @_[3 .. $#_] ] } );
}

=head2 remote_foreign_check(server, module, [api-only])

Checks if some module is installed and supported on a remote server

=cut
sub remote_foreign_check
{
return &remote_rpc_call($_[0], { 'action' => 'check',
				 'module' => $_[1],
				 'api' => $_[2] });
}

=head2 remote_foreign_config(server, module)

Gets the configuration for some module from a remote server

=cut
sub remote_foreign_config
{
return &remote_rpc_call($_[0], { 'action' => 'config',
				 'module' => $_[1] });
}

=head2 remote_eval(server, module, code)

Eval some perl code in the context of a module on a remote webmin server

=cut
sub remote_eval
{
return undef if (&is_readonly_mode());
local $sn = &remote_session_name($_[0]);
return &remote_rpc_call($_[0], { 'action' => 'eval',
				 'module' => $_[1],
				 'code' => $_[2],
				 'session' => $remote_session{$sn} });
}

=head2 remote_write(server, localfile, [remotefile], [remotebasename])

Transfers some local file to another server, and returns the resulting
remote filename.

=cut
sub remote_write
{
return undef if (&is_readonly_mode());
local ($data, $got);
local $sn = &remote_session_name($_[0]);
if (!$_[0] || $remote_server_version{$sn} >= 0.966) {
	# Copy data over TCP connection
	local $rv = &remote_rpc_call($_[0],
			{ 'action' => 'tcpwrite',
			  'file' => $_[2],
			  'name' => $_[3] } );
	local $error;
	local $serv = ref($_[0]) ? $_[0]->{'host'} : $_[0];
	&open_socket($serv || "localhost", $rv->[1], TWRITE, \$error);
	return &$remote_error_handler("Failed to transfer file : $error")
		if ($error);
	open(FILE, $_[1]);
	while(read(FILE, $got, 1024) > 0) {
		print TWRITE $got;
		}
	close(FILE);
	shutdown(TWRITE, 1);
	$error = <TWRITE>;
	if ($error && $error !~ /^OK/) {
		# Got back an error!
		return &$remote_error_handler("Failed to transfer file : $error");
		}
	close(TWRITE);
	return $rv->[0];
	}
else {
	# Just pass file contents as parameters
	open(FILE, $_[1]);
	while(read(FILE, $got, 1024) > 0) {
		$data .= $got;
		}
	close(FILE);
	return &remote_rpc_call($_[0], { 'action' => 'write',
					 'data' => $data,
					 'file' => $_[2],
					 'session' => $remote_session{$sn} });
	}
}

=head2 remote_read(server, localfile, remotefile)

MISSING DOCUMENTATION

=cut
sub remote_read
{
local $sn = &remote_session_name($_[0]);
if (!$_[0] || $remote_server_version{$sn} >= 0.966) {
	# Copy data over TCP connection
	local $rv = &remote_rpc_call($_[0],
			{ 'action' => 'tcpread', 'file' => $_[2] } );
	if (!$rv->[0]) {
		return &$remote_error_handler("Failed to transfer file : $rv->[1]");
		}
	local $error;
	local $serv = ref($_[0]) ? $_[0]->{'host'} : $_[0];
	&open_socket($serv || "localhost", $rv->[1], TREAD, \$error);
	return &$remote_error_handler("Failed to transfer file : $error")
		if ($error);
	local $got;
	open(FILE, ">$_[1]");
	while(read(TREAD, $got, 1024) > 0) {
		print FILE $got;
		}
	close(FILE);
	close(TREAD);
	}
else {
	# Just get data as return value
	local $d = &remote_rpc_call($_[0], { 'action' => 'read',
				     'file' => $_[2],
				     'session' => $remote_session{$sn} });
	open(FILE, ">$_[1]");
	print FILE $d;
	close(FILE);
	}
}

=head2 remote_finished

Close all remote sessions. This happens automatically after a while
anyway, but this function should be called to clean things up faster.

=cut
sub remote_finished
{
foreach $sn (keys %remote_session) {
	local $server = $remote_session_server{$sn};
	&remote_rpc_call($server, { 'action' => 'quit',
			            'session' => $remote_session{$sn} } );
	delete($remote_session{$sn});
	delete($remote_session_server{$sn});
	}
foreach $fh (keys %fast_fh_cache) {
	close($fh);
	delete($fast_fh_cache{$fh});
	}
}

=head2 remote_error_setup(&function)

Sets a function to be called instead of &error when a remote RPC fails

=cut
sub remote_error_setup
{
$remote_error_handler = $_[0] || "error";
}

=head2 remote_rpc_call(server, structure)

Calls rpc.cgi on some server and passes it a perl structure (hash,array,etc)
and then reads back a reply structure

=cut
sub remote_rpc_call
{
local $serv;
local $sn = &remote_session_name($_[0]);
if (ref($_[0])) {
	# Server structure was given
	$serv = $_[0];
	$serv->{'user'} || !$sn || return &$remote_error_handler(
					"No login set for server");
	}
elsif ($_[0]) {
	# lookup the server in the webmin servers module if needed
	if (!defined(%main::remote_servers_cache)) {
		&foreign_require("servers", "servers-lib.pl");
		foreach $s (&foreign_call("servers", "list_servers")) {
			$main::remote_servers_cache{$s->{'host'}} = $s;
			$main::remote_servers_cache{$s->{'host'}.":".$s->{'port'}} = $s;
			}
		}
	$serv = $main::remote_servers_cache{$_[0]};
	$serv || return &$remote_error_handler(
				"No Webmin Servers entry for $_[0]");
	$serv->{'user'} || return &$remote_error_handler(
				"No login set for server $_[0]");
	}

# Work out the username and password
local ($user, $pass);
if ($serv->{'sameuser'}) {
	$user = $remote_user;
	defined($remote_pass) || return &$remote_error_handler(
				   "Password for this server is not available");
	$pass = $remote_pass;
	}
else {
	$user = $serv->{'user'};
	$pass = $serv->{'pass'};
	}

if ($serv->{'fast'} || !$sn) {
	# Make TCP connection call to fastrpc.cgi
	if (!$fast_fh_cache{$sn} && $sn) {
		# Need to open the connection
		local $con = &make_http_connection(
			$serv->{'host'}, $serv->{'port'}, $serv->{'ssl'},
			"POST", "/fastrpc.cgi");
		return &$remote_error_handler(
		    "Failed to connect to $serv->{'host'} : $con")
			if (!ref($con));
		&write_http_connection($con, "Host: $serv->{'host'}\r\n");
		&write_http_connection($con, "User-agent: Webmin\r\n");
		local $auth = &encode_base64("$user:$pass");
		$auth =~ tr/\n//d;
		&write_http_connection($con, "Authorization: basic $auth\r\n");
		&write_http_connection($con, "Content-length: ",
					     length($tostr),"\r\n");
		&write_http_connection($con, "\r\n");
		&write_http_connection($con, $tostr);

		# read back the response
		local $line = &read_http_connection($con);
		$line =~ tr/\r\n//d;
		if ($line =~ /^HTTP\/1\..\s+401\s+/) {
			return &$remote_error_handler("Login to RPC server as $user rejected");
			}
		$line =~ /^HTTP\/1\..\s+200\s+/ ||
			return &$remote_error_handler("HTTP error : $line");
		do {
			$line = &read_http_connection($con);
			$line =~ tr/\r\n//d;
			} while($line);
		$line = &read_http_connection($con);
		if ($line =~ /^0\s+(.*)/) {
			return &$remote_error_handler("RPC error : $1");
			}
		elsif ($line =~ /^1\s+(\S+)\s+(\S+)\s+(\S+)/ ||
		       $line =~ /^1\s+(\S+)\s+(\S+)/) {
			# Started ok .. connect and save SID
			&close_http_connection($con);
			local ($port, $sid, $version, $error) = ($1, $2, $3);
			&open_socket($serv->{'host'}, $port, $sid, \$error);
			return &$remote_error_handler("Failed to connect to fastrpc.cgi : $error")
				if ($error);
			$fast_fh_cache{$sn} = $sid;
			$remote_server_version{$sn} = $version;
			}
		else {
			while($stuff = &read_http_connection($con)) {
				$line .= $stuff;
				}
			return &$remote_error_handler("Bad response from fastrpc.cgi : $line");
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
			local %acl;
			if ($base_remote_user ne 'root' &&
			    $base_remote_user ne 'admin') {
				# Need to fake up a login for the CGI!
				&read_acl(undef, \%acl);
				$ENV{'BASE_REMOTE_USER'} =
					$ENV{'REMOTE_USER'} =
						$acl{'root'} ? 'root' : 'admin';
				}
			delete($ENV{'FOREIGN_MODULE_NAME'});
			delete($ENV{'FOREIGN_ROOT_DIRECTORY'});
			chdir($root_directory);
			if (!exec("$root_directory/fastrpc.cgi")) {
				print "exec failed : $!\n";
				exit 1;
				}
			}
		close(RPCOUTw);
		local $line;
		do {
			($line = <RPCOUTr>) =~ tr/\r\n//d;
			} while($line);
		$line = <RPCOUTr>;
		#close(RPCOUTr);
		if ($line =~ /^0\s+(.*)/) {
			return &$remote_error_handler("RPC error : $2");
			}
		elsif ($line =~ /^1\s+(\S+)\s+(\S+)/) {
			# Started ok .. connect and save SID
			close(SOCK);
			local ($port, $sid, $error) = ($1, $2, undef);
			&open_socket("localhost", $port, $sid, \$error);
			return &$remote_error_handler("Failed to connect to fastrpc.cgi : $error") if ($error);
			$fast_fh_cache{$sn} = $sid;
			}
		else {
			local $_;
			while(<RPCOUTr>) {
				$line .= $_;
				}
			&error("Bad response from fastrpc.cgi : $line");
			}
		}
	# Got a connection .. send off the request
	local $fh = $fast_fh_cache{$sn};
	local $tostr = &serialise_variable($_[1]);
	print $fh length($tostr)," $fh\n";
	print $fh $tostr;
	local $rlen = int(<$fh>);
	local ($fromstr, $got);
	while(length($fromstr) < $rlen) {
		return &$remote_error_handler("Failed to read from fastrpc.cgi")
			if (read($fh, $got, $rlen - length($fromstr)) <= 0);
		$fromstr .= $got;
		}
	local $from = &unserialise_variable($fromstr);
	if (!$from) {
		return &$remote_error_handler("Remote Webmin error");
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
	local $tostr = &serialise_variable($_[1]);
	local $error = 0;
	local $con = &make_http_connection($serv->{'host'}, $serv->{'port'},
					   $serv->{'ssl'}, "POST", "/rpc.cgi");
	return &$remote_error_handler("Failed to connect to $serv->{'host'} : $con") if (!ref($con));

	&write_http_connection($con, "Host: $serv->{'host'}\r\n");
	&write_http_connection($con, "User-agent: Webmin\r\n");
	local $auth = &encode_base64("$user:$pass");
	$auth =~ tr/\n//d;
	&write_http_connection($con, "Authorization: basic $auth\r\n");
	&write_http_connection($con, "Content-length: ",length($tostr),"\r\n");
	&write_http_connection($con, "\r\n");
	&write_http_connection($con, $tostr);

	# read back the response
	local $line = &read_http_connection($con);
	$line =~ tr/\r\n//d;
	if ($line =~ /^HTTP\/1\..\s+401\s+/) {
		return &$remote_error_handler("Login to RPC server as $user rejected");
		}
	$line =~ /^HTTP\/1\..\s+200\s+/ || return &$remote_error_handler("RPC HTTP error : $line");
	do {
		$line = &read_http_connection($con);
		$line =~ tr/\r\n//d;
		} while($line);
	local $fromstr;
	while($line = &read_http_connection($con)) {
		$fromstr .= $line;
		}
	close(SOCK);
	local $from = &unserialise_variable($fromstr);
	return &$remote_error_handler("Invalid RPC login to $serv->{'host'}") if (!$from->{'status'});
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
to check if it is connectable.

=cut
sub remote_multi_callback
{
local ($servs, $parallel, $func, $args, $rets, $errs, $mod, $lib) = @_;
&remote_error_setup(\&remote_multi_callback_error);

# Call the functions
local $p = 0;
foreach my $g (@$servs) {
	local ($rh = "READ$p", $wh = "WRITE$p");
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
		local $a = ref($args) ? $args->[$p] : $args;
		local $rv = &$func($g, $a);

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
	local $rh = "READ$p";
	local $line = <$rh>;
	if (!$line) {
		$errs->[$p] = "Failed to read response from $g->{'host'}";
		}
	else {
		local $rv = &unserialise_variable($line);
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
into a url-encoded string

=cut
sub serialise_variable
{
if (!defined($_[0])) {
	return 'UNDEF';
	}
local $r = ref($_[0]);
local $rv;
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
scalar, hash ref, array ref or scalar ref.

=cut
sub unserialise_variable
{
local @v = split(/,/, $_[0]);
local ($rv, $i);
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
	for($i=1; $i<@v; $i++) {
		push(@$rv, &unserialise_variable(&un_urlize($v[$i])));
		}
	}
elsif ($v[0] eq 'HASH') {
	$rv = { };
	for($i=1; $i<@v; $i+=2) {
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
	local $cls = $1;
	$rv = { };
	for($i=1; $i<@v; $i+=2) {
		$rv->{&unserialise_variable(&un_urlize($v[$i]))} =
			&unserialise_variable(&un_urlize($v[$i+1]));
		}
	eval "use $cls";
	bless $rv, $cls;
	}
return $rv;
}

=head2 other_groups(user)

Returns a list of secondary groups a user is a member of

=cut
sub other_groups
{
local (@rv, @g);
setgrent();
while(@g = getgrent()) {
	local @m = split(/\s+/, $g[3]);
	push(@rv, $g[2]) if (&indexof($_[0], @m) >= 0);
	}
endgrent() if ($gconfig{'os_type'} ne 'hpux');
return @rv;
}

=head2 date_chooser_button(dayfield, monthfield, yearfield)

Returns HTML for a date-chooser button

=cut
sub date_chooser_button
{
return &theme_date_chooser_button(@_)
	if (defined(&theme_date_chooser_button));
local ($w, $h) = (250, 225);
if ($gconfig{'db_sizedate'}) {
	($w, $h) = split(/x/, $gconfig{'db_sizedate'});
	}
return "<input type=button onClick='window.dfield = form.$_[0]; window.mfield = form.$_[1]; window.yfield = form.$_[2]; window.open(\"$gconfig{'webprefix'}/date_chooser.cgi?day=\"+escape(dfield.value)+\"&month=\"+escape(mfield.selectedIndex)+\"&year=\"+yfield.value, \"chooser\", \"toolbar=no,menubar=no,scrollbars=yes,width=$w,height=$h\")' value=\"...\">\n";
}

=head2 help_file(module, file)

Returns the path to a module's help file

=cut
sub help_file
{
local $mdir = &module_root_directory($_[0]);
local $dir = "$mdir/help";
foreach my $o (@lang_order_list) {
	local $lang = "$dir/$_[1].$current_lang.html";
	return $lang if (-r $lang);
	}
return "$dir/$_[1].html";
}

=head2 seed_random

Seeds the random number generator, if needed

=cut
sub seed_random
{
if (!$main::done_seed_random) {
	if (open(RANDOM, "/dev/urandom")) {
		local $buf;
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

Returns the number of kb used by some directory and all subdirs

=cut
sub disk_usage_kb
{
local $dir = &translate_filename($_[0]);
local $out;
local $ex = &execute_command("du -sk ".quotemeta($dir), undef, \$out, undef,
			     0, 1);
if ($ex) {
	&execute_command("du -s ".quotemeta($dir), undef, \$out, undef,
			 0, 1);
	}
return $out =~ /^([0-9]+)/ ? $1 : "???";
}

=head2 recursive_disk_usage(directory)

Returns the number of bytes taken up by all files in some directory

=cut
sub recursive_disk_usage
{
local $dir = &translate_filename($_[0]);
if (-l $dir) {
	return 0;
	}
elsif (!-d $dir) {
	local @st = stat($dir);
	return $st[7];
	}
else {
	local $rv = 0;
	opendir(DIR, $dir);
	local @files = readdir(DIR);
	closedir(DIR);
	foreach my $f (@files) {
		next if ($f eq "." || $f eq "..");
		$rv += &recursive_disk_usage("$dir/$f");
		}
	return $rv;
	}
}

=head2 help_search_link(term, [ section, ... ] )

Returns HTML for a link to the man module for searching local and online
docs for various search terms

=cut
sub help_search_link
{
local %acl;
if (&foreign_available("man") && !$tconfig{'nosearch'}) {
	local $for = &urlize(shift(@_));
	return "<a href='$gconfig{'webprefix'}/man/search.cgi?".
	       join("&", map { "section=$_" } @_)."&".
	       "for=$for&exact=1&check=$module_name'>".
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

=cut
sub make_http_connection
{
local ($host, $port, $ssl, $method, $page, $headers) = @_;
local $htxt;
if ($headers) {
	foreach my $h (@$headers) {
		$htxt .= $h->[0].": ".$h->[1]."\r\n";
		}
	$htxt .= "\r\n";
	}
if (&is_readonly_mode()) {
	return "HTTP connections not allowed in readonly mode";
	}
local $rv = { 'fh' => time().$$ };
if ($ssl) {
	# Connect using SSL
	eval "use Net::SSLeay";
	$@ && return $text{'link_essl'};
	eval "Net::SSLeay::SSLeay_add_ssl_algorithms()";
	eval "Net::SSLeay::load_error_strings()";
	$rv->{'ssl_ctx'} = Net::SSLeay::CTX_new() ||
		return "Failed to create SSL context";
	$rv->{'ssl_con'} = Net::SSLeay::new($rv->{'ssl_ctx'}) ||
		return "Failed to create SSL connection";
	local $connected;
	if ($gconfig{'http_proxy'} =~ /^http:\/\/(\S+):(\d+)/ &&
	    !&no_proxy($host)) {
		# Via proxy
		local $error;
		&open_socket($1, $2, $rv->{'fh'}, \$error);
		if (!$error) {
			# Connected OK
			local $fh = $rv->{'fh'};
			print $fh "CONNECT $host:$port HTTP/1.0\r\n";
			if ($gconfig{'proxy_user'}) {
				local $auth = &encode_base64(
				   "$gconfig{'proxy_user'}:".
				   "$gconfig{'proxy_pass'}");
				$auth =~ tr/\r\n//d;
				print $fh "Proxy-Authorization: Basic $auth\r\n";
				}
			print $fh "\r\n";
			local $line = <$fh>;
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
		local $error;
		&open_socket($host, $port, $rv->{'fh'}, \$error);
		return $error if ($error);
		}
	Net::SSLeay::set_fd($rv->{'ssl_con'}, fileno($rv->{'fh'}));
	Net::SSLeay::connect($rv->{'ssl_con'}) ||
		return "SSL connect() failed";
	local $rtxt = "$method $page HTTP/1.0\r\n".$htxt;
	Net::SSLeay::write($rv->{'ssl_con'}, $rtxt);
	}
else {
	# Plain HTTP request
	local $connected;
	if ($gconfig{'http_proxy'} =~ /^http:\/\/(\S+):(\d+)/ &&
	    !&no_proxy($host)) {
		# Via a proxy
		local $error;
		&open_socket($1, $2, $rv->{'fh'}, \$error);
		if (!$error) {
			# Connected OK
			$connected = 1;
			local $fh = $rv->{'fh'};
			local $rtxt = "$method http://$host:$port$page HTTP/1.0\r\n";
			if ($gconfig{'proxy_user'}) {
				local $auth = &encode_base64(
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
		local $error;
		&open_socket($host, $port, $rv->{'fh'}, \$error);
		return $error if ($error);
		local $fh = $rv->{'fh'};
		local $rtxt = "$method $page HTTP/1.0\r\n".$htxt;
		print $fh $rtxt;
		}
	}
return $rv;
}

=head2 read_http_connection(handle, [amount])

Reads either one line or up to the specified amount of data from the handle

=cut
sub read_http_connection
{
local $h = $_[0];
local $rv;
if ($h->{'ssl_con'}) {
	if (!$_[1]) {
		local ($idx, $more);
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
			$rv = Net::SSLeay::read($h->{'ssl_con'}, $_[1]);
			}
		}
	}
else {
	if ($_[1]) {
		read($h->{'fh'}, $rv, $_[1]) > 0 || return undef;
		}
	else {
		local $fh = $h->{'fh'};
		$rv = <$fh>;
		}
	}
$rv = undef if ($rv eq "");
return $rv;
}

=head2 write_http_connection(handle, [data+])

Writes the given data to the handle

=cut
sub write_http_connection
{
local $h = shift(@_);
local $fh = $h->{'fh'};
if ($h->{'ssl_ctx'}) {
	foreach (@_) {
		Net::SSLeay::write($h->{'ssl_con'}, $_);
		}
	}
else {
	print $fh @_;
	}
}

=head2 close_http_connection(handle)

MISSING DOCUMENTATION

=cut
sub close_http_connection
{
close($h->{'fh'});
}

=head2 clean_environment

Deletes any environment variables inherited from miniserv so that they
won't be passed to programs started by webmin.

=cut
sub clean_environment
{
local ($k, $e);
%UNCLEAN_ENV = %ENV;
foreach $k (keys %ENV) {
	if ($k =~ /^(HTTP|VIRTUALSERVER|QUOTA|USERADMIN)_/) {
		delete($ENV{$k});
		}
	}
foreach $e ('WEBMIN_CONFIG', 'SERVER_NAME', 'CONTENT_TYPE', 'REQUEST_URI',
	    'PATH_INFO', 'WEBMIN_VAR', 'REQUEST_METHOD', 'GATEWAY_INTERFACE',
	    'QUERY_STRING', 'REMOTE_USER', 'SERVER_SOFTWARE', 'SERVER_PROTOCOL',
	    'REMOTE_HOST', 'SERVER_PORT', 'DOCUMENT_ROOT', 'SERVER_ROOT',
	    'MINISERV_CONFIG', 'SCRIPT_NAME', 'SERVER_ADMIN', 'CONTENT_LENGTH',
	    'HTTPS', 'FOREIGN_MODULE_NAME', 'FOREIGN_ROOT_DIRECTORY',
	    'SCRIPT_FILENAME', 'PATH_TRANSLATED', 'BASE_REMOTE_USER',
	    'DOCUMENT_REALROOT', 'MINISERV_CONFIG', 'MYSQL_PWD') {
	delete($ENV{$e});
	}
}

=head2 reset_environment

Puts the environment back how it was before &clean_environment

=cut
sub reset_environment
{
if (defined(%UNCLEAN_ENV)) {
	foreach my $k (keys %UNCLEAN_ENV) {
		$ENV{$k} = $UNCLEAN_ENV{$k};
		}
	undef(%UNCLEAN_ENV);
	}
}

$webmin_feedback_address = "feedback\@webmin.com";

=head2 progress_callback

Never called directly, but useful for passing to &http_download

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
		print &text('progress_size', $progress_callback_url,
			    $progress_size),"<br>\n";
		}
	else {
		print &text('progress_nosize', $progress_callback_url),"<br>\n";
		}
	$last_progress_time = $last_progress_size = undef;
	}
elsif ($_[0] == 3) {
	# Got data update
	local $sp = $progress_callback_prefix.("&nbsp;" x 5);
	if ($progress_size) {
		# And we have a size to compare against
		local $st = int(($_[1] * 10) / $progress_size);
		local $time_now = time();
		if ($st != $progress_step ||
		    $time_now - $last_progress_time > 60) {
			# Show progress every 10% or 60 seconds
			print $sp,&text('progress_data', $_[1], int($_[1]*100/$progress_size)),"<br>\n";
			$last_progress_time = $time_now;
			}
		$progress_step = $st;
		}
	else {
		# No total size .. so only show in 100k jumps
		if ($_[1] > $last_progress_size+100*1024) {
			print $sp,&text('progress_data2', $_[1]),"<br>\n";
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

=cut
sub switch_to_remote_user
{
@remote_user_info = $remote_user ? getpwnam($remote_user) :
		    		   getpwuid($<);
@remote_user_info || &error(&text('switch_remote_euser', $remote_user));
&create_missing_homedir(\@remote_user_info);
if ($< == 0) {
	($(, $)) = ( $remote_user_info[3],
		     "$remote_user_info[3] ".join(" ", $remote_user_info[3],
				       &other_groups($remote_user_info[0])) );
	($>, $<) = ( $remote_user_info[2], $remote_user_info[2] );
	$ENV{'USER'} = $ENV{'LOGNAME'} = $remote_user;
	$ENV{'HOME'} = $remote_user_info[7];
	}
}

=head2 create_user_config_dirs

Creates per-user config directories and sets $user_config_directory and
$user_module_config_directory to them. Also reads per-user module configs
into %userconfig

=cut
sub create_user_config_dirs
{
return if (!$gconfig{'userconfig'});
local @uinfo = @remote_user_info ? @remote_user_info : getpwnam($remote_user);
return if (!@uinfo || !$uinfo[7]);
&create_missing_homedir(\@uinfo);
$user_config_directory = "$uinfo[7]/$gconfig{'userconfig'}";
if (!-d $user_config_directory) {
	mkdir($user_config_directory, 0755) ||
		&error("Failed to create $user_config_directory : $!");
	if ($< == 0 && $uinfo[2]) {
		chown($uinfo[2], $uinfo[3], $user_config_directory);
		}
	}
if ($module_name) {
	$user_module_config_directory = "$user_config_directory/$module_name";
	if (!-d $user_module_config_directory) {
		mkdir($user_module_config_directory, 0755) ||
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
}

=head2 create_missing_homedir(&uinfo)

If auto homedir creation is enabled, create one for this user if needed

=cut
sub create_missing_homedir
{
local ($uinfo) = @_;
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

Disables all javascript <script>, onClick= and so on tags in the given HTML

=cut
sub filter_javascript
{
local $rv = $_[0];
$rv =~ s/<\s*script[^>]*>([\000-\377]*?)<\s*\/script\s*>//gi;
$rv =~ s/(on(Abort|Blur|Change|Click|DblClick|DragDrop|Error|Focus|KeyDown|KeyPress|KeyUp|Load|MouseDown|MouseMove|MouseOut|MouseOver|MouseUp|Move|Reset|Resize|Select|Submit|Unload)=)/x$1/gi;
$rv =~ s/(javascript:)/x$1/gi;
$rv =~ s/(vbscript:)/x$1/gi;
return $rv;
}

=head2 resolve_links(path)

Given a path that may contain symbolic links, returns the real path

=cut
sub resolve_links
{
local $path = $_[0];
$path =~ s/\/+/\//g;
$path =~ s/\/$// if ($path ne "/");
local @p = split(/\/+/, $path);
shift(@p);
local $i;
for($i=0; $i<@p; $i++) {
	local $sofar = "/".join("/", @p[0..$i]);
	local $lnk = readlink($sofar);
	if ($lnk =~ /^\//) {
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

Given a path, maybe containing stuff like ".." and "." convert it to a
clean, absolute form. Returns undef if this is not possible

=cut
sub simplify_path
{
local($dir, @bits, @fixedbits, $b);
$dir = $_[0];
$dir =~ s/^\/+//g;
$dir =~ s/\/+$//g;
@bits = split(/\/+/, $dir);
@fixedbits = ();
$_[1] = 0;
foreach $b (@bits) {
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
return "/" . join('/', @fixedbits);
}

=head2 same_file(file1, file2)

Returns 1 if two files are actually the same

=cut
sub same_file
{
return 1 if ($_[0] eq $_[1]);
return 0 if ($_[0] !~ /^\// || $_[1] !~ /^\//);
local @stat1 = $stat_cache{$_[0]} ? @{$stat_cache{$_[0]}}
			          : (@{$stat_cache{$_[0]}} = stat($_[0]));
local @stat2 = $stat_cache{$_[1]} ? @{$stat_cache{$_[1]}}
			          : (@{$stat_cache{$_[1]}} = stat($_[1]));
return 0 if (!@stat1 || !@stat2);
return $stat1[0] == $stat2[0] && $stat1[1] == $stat2[1];
}

=head2 flush_webmin_caches

Clears all in-memory and on-disk caches used by webmin

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
&get_all_module_infos();
}

=head2 list_usermods

Returns a list of additional module restrictions. For internal use in
usermin only.

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
on usermod additional/subtractions

=cut
sub available_usermods
{
return @{$_[0]} if (!@{$_[1]});

local %mods;
map { $mods{$_->{'dir'}}++ } @{$_[0]};
local @uinfo = @remote_user_info;
@uinfo = getpwnam($remote_user) if (!@uinfo);
foreach $u (@{$_[1]}) {
	local $applies;
	if ($u->[0] eq "*" || $u->[0] eq $remote_user) {
		$applies++;
		}
	elsif ($u->[0] =~ /^\@(.*)$/) {
		# Check for group membership
		local @ginfo = getgrnam($1);
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
				local @ginfo = getgrnam($1);
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
operating system support, access control and usermod restrictions.

=cut
sub get_available_module_infos
{
local (%acl, %uacl);
&read_acl(\%acl, \%uacl);
local $risk = $gconfig{'risk_'.$base_remote_user};
local ($minfo, @rv, $m);
foreach $minfo (&get_all_module_infos($_[0])) {
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
local @usermods = &list_usermods();
@rv = sort { $a->{'desc'} cmp $b->{'desc'} }
	    &available_usermods(\@rv, \@usermods);

# Check RBAC restrictions
local @rbacrv;
foreach $m (@rv) {
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
local @themerv;
if (defined(&theme_foreign_available)) {
	foreach $m (@rbacrv) {
		if (&theme_foreign_available($m->{'dir'})) {
			push(@themerv, $m);
			}
		}
	}
else {
	@themerv = @rbacrv;
	}

# Check licence module vetos
local @licrv;
if ($main::licence_module) {
	foreach $m (@themerv) {
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

Like get_available_module_infos, but excludes hidden modules from the list

=cut
sub get_visible_module_infos
{
local ($nocache) = @_;
local $pn = &get_product_name();
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
local ($nocache) = @_;
local @mods = &get_visible_module_infos($nocache);
local @unmods;
if (&get_product_name() eq 'webmin') {
	@unmods = grep { $_->{'installed'} eq '0' } @mods;
	@mods = grep { $_->{'installed'} ne '0' } @mods;
	}
local %cats = &list_categories(\@mods);
local @rv;
foreach my $c (keys %cats) {
	local $cat = { 'code' => $c || 'other',
		       'desc' => $cats{$c} };
	$cat->{'modules'} = [ grep { $_->{'category'} eq $c } @mods ];
	push(@rv, $cat);
	}
@rv = sort { ($b->{'code'} eq "others" ? "" : $b->{'code'}) cmp
	     ($a->{'code'} eq "others" ? "" : $a->{'code'}) } @rv;
if (@unmods) {
	# Add un-installed modules in magic category
	local $cat = { 'code' => 'unused',
		       'desc' => $text{'main_unused'},
		       'unused' => 1,
		       'modules' => \@unmods };
	push(@rv, $cat);
	}
return @rv;
}

=head2 is_under_directory(directory, file)

Returns 1 if the given file is under the specified directory, 0 if not.
Symlinks are taken into account in the file to find it's 'real' location

=cut
sub is_under_directory
{
local ($dir, $file) = @_;
return 1 if ($dir eq "/");
return 0 if ($file =~ /\.\./);
local $ld = &resolve_links($dir);
if ($ld ne $dir) {
	return &resolve_links($ld, $file);
	}
local $lp = &resolve_links($file);
if ($lp ne $file) {
	return &is_under_directory($dir, $lp);
	}
return 0 if (length($file) < length($dir));
return 1 if ($dir eq $file);
$dir =~ s/\/*$/\//;
return substr($file, 0, length($dir)) eq $dir;
}

=head2 parse_http_url(url, [basehost, baseport, basepage, basessl])

Given an absolute URL, returns the host, port, page and ssl components.
Relative URLs can also be parsed, if the base information is provided

=cut
sub parse_http_url
{
if ($_[0] =~ /^(http|https):\/\/([^:\/]+)(:(\d+))?(\/\S*)?$/) {
	# An absolute URL
	local $ssl = $1 eq 'https';
	return ($2, $3 ? $4 : $ssl ? 443 : 80, $5 || "/", $ssl);
	}
elsif (!$_[1]) {
	# Could not parse
	return undef;
	}
elsif ($_[0] =~ /^\/\S*$/) {
	# A relative to the server URL
	return ($_[1], $_[2], $_[0], $_[4]);
	}
else {
	# A relative to the directory URL
	local $page = $_[3];
	$page =~ s/[^\/]+$//;
	return ($_[1], $_[2], $page.$_[0], $_[4]);
	}
}

=head2 check_clicks_function

Returns HTML for a JavaScript function called check_clicks that returns
true when first called, but false subsequently. Useful on onClick for
critical buttons.

=cut
sub check_clicks_function
{
return <<EOF;
<script>
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
ascii values (like 246)

=cut
sub load_entities_map
{
if (!defined(%entities_map_cache)) {
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
with their ASCII equivalents

=cut
sub entities_to_ascii
{
local $str = $_[0];
local $emap = &load_entities_map();
$str =~ s/&([a-z]+);/chr($emap->{$1})/ge;
$str =~ s/&#(\d+);/chr($1)/ge;
return $str;
}

=head2 get_product_name

Returns either 'webmin' or 'usermin'

=cut
sub get_product_name
{
return $gconfig{'product'} if (defined($gconfig{'product'}));
return defined($gconfig{'userconfig'}) ? 'usermin' : 'webmin';
}

$default_charset = "iso-8859-1";

=head2 get_charset

Returns the character set for the current language

=cut
sub get_charset
{
local $charset = defined($gconfig{'charset'}) ? $gconfig{'charset'} :
		 $current_lang_info->{'charset'} ?
		 $current_lang_info->{'charset'} : $default_charset;
return $charset;
}

=head2 get_display_hostname

Returns the system's hostname for UI display purposes

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
	local $h = $ENV{'HTTP_HOST'};
	$h =~ s/:\d+//g;
	if ($gconfig{'hostnamemode'} == 2) {
		$h =~ s/^(www|ftp|mail)\.//i;
		}
	return $h;
	}
}

=head2 save_module_config([&config], [modulename])

Saves the configuration for some module

=cut
sub save_module_config
{
local $c = $_[0] || \%config;
local $m = defined($_[1]) ? $_[1] : $module_name;
&write_file("$config_directory/$m/config", $c);
}

=head2 save_user_module_config([&config], [modulename])

Saves the user's Usermin configuration for some module

=cut
sub save_user_module_config
{
local $c = $_[0] || \%userconfig;
local $m = $_[1] || $module_name;
local $ucd = $user_config_directory;
if (!$ucd) {
	local @uinfo = @remote_user_info ? @remote_user_info
					 : getpwnam($remote_user);
	return if (!@uinfo || !$uinfo[7]);
	$ucd = "$uinfo[7]/$gconfig{'userconfig'}";
	}
&write_file("$ucd/$m/config", $c);
}

=head2 nice_size(bytes, [min])

Converts a number of bytes into a number of bytes, kb, mb or gb

=cut
sub nice_size
{
local ($units, $uname);
if ($_[0] > 1024*1024*1024*1024 || $_[1] >= 1024*1024*1024*1024) {
	$units = 1024*1024*1024*1024;
	$uname = "TB";
	}
elsif ($_[0] > 1024*1024*1024 || $_[1] >= 1024*1024*1024) {
	$units = 1024*1024*1024;
	$uname = "GB";
	}
elsif ($_[0] > 1024*1024 || $_[1] >= 1024*1024) {
	$units = 1024*1024;
	$uname = "MB";
	}
elsif ($_[0] > 1024 || $_[1] >= 1024) {
	$units = 1024;
	$uname = "kB";
	}
else {
	$units = 1;
	$uname = "bytes";
	}
local $sz = sprintf("%.2f", ($_[0]*1.0 / $units));
$sz =~ s/\.00$//;
return $sz." ".$uname;
}

=head2 get_perl_path

Returns the path to Perl currently in use

=cut
sub get_perl_path
{
local $rv;
if (open(PERL, "$config_directory/perl-path")) {
	chop($rv = <PERL>);
	close(PERL);
	return $rv;
	}
return $^X if (-x $^X);
return &has_command("perl");
}

=head2 get_goto_module([&mods])

Returns the details of a module that the current user should be re-directed
to after logging in, or undef if none

=cut
sub get_goto_module
{
local @mods = $_[0] ? @{$_[0]} : &get_visible_module_infos();
if ($gconfig{'gotomodule'}) {
	local ($goto) = grep { $_->{'dir'} eq $gconfig{'gotomodule'} } @mods;
	return $goto if ($goto);
	}
if (@mods == 1 && $gconfig{'gotoone'}) {
	return $mods[0];
	}
return undef;
}

=head2 select_all_link(field, form, text)

Returns HTML for a 'Select all' link that uses Javascript to select
multiple checkboxes with the same name

=cut
sub select_all_link
{
return &theme_select_all_link(@_) if (defined(&theme_select_all_link));
local ($field, $form, $text) = @_;
$form = int($form);
$text ||= $text{'ui_selall'};
return "<a class='select_all' href='#' onClick='document.forms[$form].$field.checked = true; for(i=0; i<document.forms[$form].$field.length; i++) { document.forms[$form].${field}[i].checked = true; } return false'>$text</a>";
}

=head2 select_invert_link(field, form, text)

Returns HTML for a 'Select all' link that uses Javascript to invert the
selection on multiple checkboxes with the same name

=cut
sub select_invert_link
{
return &theme_select_invert_link(@_) if (defined(&theme_select_invert_link));
local ($field, $form, $text) = @_;
$form = int($form);
$text ||= $text{'ui_selinv'};
return "<a class='select_invert' href='#' onClick='document.forms[$form].$field.checked = !document.forms[$form].$field.checked; for(i=0; i<document.forms[$form].$field.length; i++) { document.forms[$form].${field}[i].checked = !document.forms[$form].${field}[i].checked; } return false'>$text</a>";
}

=head2 select_rows_link(field, form, text, &rows)

Returns HTML for a link that uses Javascript to select rows with particular
values for their checkboxes

=cut
sub select_rows_link
{
return &theme_select_rows_link(@_) if (defined(&theme_select_rows_link));
local ($field, $form, $text, $rows) = @_;
$form = int($form);
local $js = "var sel = { ".join(",", map { "\"".&quote_escape($_)."\":1" } @$rows)." }; ";
$js .= "for(var i=0; i<document.forms[$form].${field}.length; i++) { var r = document.forms[$form].${field}[i]; r.checked = sel[r.value]; } ";
$js .= "return false;";
return "<a href='#' onClick='$js'>$text</a>";
}

=head2 check_pid_file(file)

Given a pid file, returns the PID it contains if the process is running

=cut
sub check_pid_file
{
open(PIDFILE, $_[0]) || return undef;
local $pid = <PIDFILE>;
close(PIDFILE);
$pid =~ /^\s*(\d+)/ || return undef;
kill(0, $1) || return undef;
return $1;
}

=head2 get_mod_lib


Return the local os-specific library name to this module


=cut
sub get_mod_lib
{
local $lib;
if (-r "$module_root_directory/$module_name-$gconfig{'os_type'}-$gconfig{'os_version'}-lib.pl") {
        return "$module_name-$gconfig{'os_type'}-$gconfig{'os_version'}-lib.pl";
        }
elsif (-r "$module_root_directory/$module_name-$gconfig{'os_type'}-lib.pl") {
        return "$module_name-$gconfig{'os_type'}-lib.pl";
        }
elsif (-r "$module_root_directory/$module_name-generic-lib.pl") {
        return "$module_name-generic-lib.pl";
        }
else {
	return "";
	}
}

=head2 module_root_directory(module)

Given a module name, returns its root directory

=cut
sub module_root_directory
{
local $d = ref($_[0]) ? $_[0]->{'dir'} : $_[0];
if (@root_directories > 1) {
	local $r;
	foreach $r (@root_directories) {
		if (-d "$r/$d") {
			return "$r/$d";
			}
		}
	}
return "$root_directories[0]/$d";
}

=head2 list_mime_types

Returns a list of all known MIME types and their extensions

=cut
sub list_mime_types
{
if (!@list_mime_types_cache) {
	local $_;
	open(MIME, "$root_directory/mime.types");
	while(<MIME>) {
		local $cmt;
		s/\r|\n//g;
		if (s/#\s*(.*)$//g) {
			$cmt = $1;
			}
		local ($type, @exts) = split(/\s+/);
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

Given a file name like xxx.gif or foo.html, returns a guessed MIME type

=cut
sub guess_mime_type
{
if ($_[0] =~ /\.([A-Za-z0-9\-]+)$/) {
	local $ext = $1;
	local ($t, $e);
	foreach $t (&list_mime_types()) {
		foreach $e (@{$t->{'exts'}}) {
			return $t->{'type'} if (lc($e) eq lc($ext));
			}
		}
	}
return @_ > 1 ? $_[1] : "application/octet-stream";
}

=head2 open_tempfile([handle], file, [no-error], [no-tempfile], [safe?])

Returns a temporary file for writing to some actual file

=cut
sub open_tempfile
{
if (@_ == 1) {
	# Just getting a temp file
	if (!defined($main::open_tempfiles{$_[0]})) {
		$_[0] =~ /^(.*)\/(.*)$/ || return $_[0];
		local $dir = $1 || "/";
		local $tmp = "$dir/$2.webmintmp.$$";
		$main::open_tempfiles{$_[0]} = $tmp;
		push(@main::temporary_files, $tmp);
		}
	return $main::open_tempfiles{$_[0]};
	}
else {
	# Actually opening
	local ($fh, $file, $noerror, $notemp, $safe) = @_;
	local %gaccess = &get_module_acl(undef, "");
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
			  $l eq ">>" ? "APPEND" : "READ", "nul") if ($db);
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
		local $tmp = &open_tempfile($file);
		local $ex = open($fh, ">$tmp");
		if (!$ex && $! =~ /permission/i) {
			# Could not open temp file .. try opening actual file
			# instead directly
			$ex = open($fh, ">$file");
			delete($main::open_tempfiles{$file});
			}
		else {
			$main::open_temphandles{$fh} = $file;
			}
		binmode($fh);
		if (!$ex && !$noerror) {
			&error(&text("efileopen", $file, $!));
			}
		return $ex;
		}
	elsif ($file =~ /^>\s*(([a-zA-Z]:)?\/.*)$/ && $notemp) {
		# Just writing direct to a file
		&webmin_debug_log("WRITE", $1) if ($db);
		$file = $1;
		$file = &translate_filename($file);
		my @old_attributes = &get_clear_file_attributes($file);
		local $ex = open($fh, ">$file");
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
		local $ex = open($fh, ">>$file");
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
		local ($package, $filename, $line) = caller;
		if ($noerror) { return 0; }
		else { &error("Missing file to open at ${package}::${filename} line $line"); }
		}
	else {
		# XXX append / update support?
		local ($package, $filename, $line) = caller;
		&error("Unsupported file or mode $file at ${package}::${filename} line $line");
		}
	}
}

=head2 close_tempfile(file|handle)

Copies a temp file to the actual file, assuming that all writes were
successful.

=cut
sub close_tempfile
{
local $file;
if (defined($file = $main::open_temphandles{$_[0]})) {
	# Closing a handle
	close($_[0]) || &error(&text("efileclose", $file, $!));
	delete($main::open_temphandles{$_[0]});
	return &close_tempfile($file);
	}
elsif (defined($main::open_tempfiles{$_[0]})) {
	# Closing a file
	&webmin_debug_log("CLOSE", $_[0]) if ($gconfig{'debug_what_write'});
	local @st = stat($_[0]);
	if (&is_selinux_enabled() && &has_command("chcon")) {
		# Set original security context
		system("chcon --reference=".quotemeta($_[0]).
		       " ".quotemeta($main::open_tempfiles{$_[0]}).
		       " >/dev/null 2>&1");
		}
	my @old_attributes = &get_clear_file_attributes($_[0]);
	rename($main::open_tempfiles{$_[0]}, $_[0]) || &error("Failed to replace $_[0] with $main::open_tempfiles{$_[0]} : $!");
	if (@st) {
		# Set original permissions and ownership
		chmod($st[2], $_[0]);
		chown($st[4], $st[5], $_[0]);
		}
	&reset_file_attributes($_[0], \@old_attributes);
	delete($main::open_tempfiles{$_[0]});
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

=head2 is_selinux_enabled

Returns 1 if SElinux is supported on this system and enabled

=cut
sub is_selinux_enabled
{
if (!defined($main::selinux_enabled_cache)) {
	local %seconfig;
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
as a list. May call error.

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

Put back cleared attributes on some file. May call error.

=cut
sub reset_file_attributes
{
local ($file, $old_attributes) = @_;
if (&indexof("i", @$old_attributes) >= 0) {
	my $err = &backquote_logged(
		"chattr +i ".quotemeta($file)." 2>&1");
	if ($?) {
		&error("Failed to restore immutable bit on ".
		       "$file : $err");
		}
	}
}

=head2 print_tempfile(handle, text, ...)

Like the normal print function, but calls &error on failure

=cut
sub print_tempfile
{
local ($fh, @args) = @_;
(print $fh @args) || &error(&text("efilewrite",
			    $main::open_temphandles{$fh} || $fh, $!));
}

=head2 cleanup_tempnames

Remove all temporary files

=cut
sub cleanup_tempnames
{
local $t;
foreach $t (@main::temporary_files) {
	&unlink_file($t);
	}
@main::temporary_files = ( );
}

=head2 open_lock_tempfile([handle], file, [no-error])

Returns a temporary file for writing to some actual file, and also locks it

=cut
sub open_lock_tempfile
{
local $file = @_ == 1 ? $_[0] : $_[1];
$file =~ s/^[^\/]*//;
if ($file =~ /^\//) {
	$main::open_templocks{$file} = &lock_file($file);
	}
return &open_tempfile(@_);
}

sub END
{
$main::end_exit_status ||= $?;
if ($$ == $main::initial_process_id) {
	# Exiting from initial process
	&cleanup_tempnames();
	if ($gconfig{'debug_what_start'} && $main::debug_log_start_time &&
	    $main::debug_log_start_module eq $module_name) {
		local $len = time() - $main::debug_log_start_time;
		&webmin_debug_log("STOP", "runtime=$len");
		$main::debug_log_start_time = 0;
		}
	if (!$ENV{'SCRIPT_NAME'} &&
	    $main::initial_module_name eq $module_name) {
		# In a command-line script - call the real exit, so that the
		# exit status gets properly propogated. In some cases this
		# was not happening.
		exit($main::end_exit_status);
		}
	}
}

=head2 month_to_number(month)

Converts a month name like feb to a number like 1

=cut
sub month_to_number
{
return $month_to_number_map{lc(substr($_[0], 0, 3))};
}

=head2 number_to_month(number)

Converts a number like 1 to a month name like Feb

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
local ($user, $mod) = @_;
eval "use Authen::SolarisRBAC";
return undef if ($@);
local %rv;
local $foundany = 0;
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
	local ($auths, $acls) = split(/\s+/, $_);
	local @auths = split(/,/, $auths);
	next if (!$auths);
	local ($merge) = ($acls =~ s/^\+//);
	local $a;
	local $gotall = 1;
	if ($auths eq "*") {
		# These ACLs apply to all RBAC users.
		# Only if there is some that match a specific authorization
		# later will they be used though.
		}
	else {
		# Check each of the RBAC authorizations
		foreach $a (@auths) {
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
		local %acl = map { split(/=/, $_, 2) }
				 split(/,/, $acls);
		if ($merge) {
			# Just add to current set
			foreach $a (keys %acl) {
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
return !$foundany ? undef : defined(%rv) ? \%rv : undef;
}

=head2 supports_rbac([module])

Returns 1 if RBAC client support is available

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

# use_rbac_module_acl(user, module)
# Returns 1 if some user should use RBAC to get permissions for a module
sub use_rbac_module_acl(user, module)
{
local $u = defined($_[0]) ? $_[0] : $base_remote_user;
local $m = defined($_[1]) ? $_[1] : $module_name;
return 1 if ($gconfig{'rbacdeny_'.$u});		# RBAC forced for user
local %access = &get_module_acl($u, $m, 1);
return $access{'rbac'} ? 1 : 0;
}

=head2 execute_command(command, stdin, stdout, stderr, translate-files?, safe?)

Runs some command, possibly feeding it input and capturing output to the
give files or scalar references.

=cut
sub execute_command
{
local ($cmd, $stdin, $stdout, $stderr, $trans, $safe) = @_;
if (&is_readonly_mode() && !$safe) {
	print STDERR "Vetoing command $_[0]\n";
	$? = 0;
	return 0;
	}
local $cmd = &translate_command($cmd);

# Use ` operator where possible
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
&webmin_debug_log('CMD', "cmd=$cmd") if ($gconfig{'debug_what_cmd'});

# Setup pipes
$| = 1;		# needed on some systems to flush before forking
pipe(EXECSTDINr, EXECSTDINw);
pipe(EXECSTDOUTr, EXECSTDOUTw);
pipe(EXECSTDERRr, EXECSTDERRw);
local $pid;
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

	local $fullcmd = "($cmd)";
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

Opens some file for reading. Returns 1 on success, 0 on failure

=cut
sub open_readfile
{
local ($fh, $file) = @_;
local $realfile = &translate_filename($file);
&webmin_debug_log('READ', $file) if ($gconfig{'debug_what_read'});
return open($fh, "<".$realfile);
}

=head2 open_execute_command(handle, command, output?, safe?)

Runs some command, with the specified filename set to either write to it if
in-or-out is set to 0, or read to it if output is set to 1.

=cut
sub open_execute_command
{
local ($fh, $cmd, $mode, $safe) = @_;
local $realcmd = &translate_command($cmd);
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
&webmin_debug_log('CMD', "cmd=$realcmd mode=$mode")
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

Applies all relevant registered translation functions to a filename

=cut
sub translate_filename
{
local $realfile = $_[0];
local @funcs = grep { $_->[0] eq $module_name ||
		      !defined($_->[0]) } @main::filename_callbacks;
local $f;
foreach $f (@funcs) {
	local $func = $f->[1];
	$realfile = &$func($realfile, @{$f->[2]});
	}
return $realfile;
}

=head2 translate_command(filename)

Applies all relevant registered translation functions to a command

=cut
sub translate_command
{
local $realcmd = $_[0];
local @funcs = grep { $_->[0] eq $module_name ||
		      !defined($_->[0]) } @main::command_callbacks;
local $f;
foreach $f (@funcs) {
	local $func = $f->[1];
	$realcmd = &$func($realcmd, @{$f->[2]});
	}
return $realcmd;
}

=head2 register_filename_callback(module|undef, &function, &args)

Registers some function to be called when the specified module (or all
modules) tries to open a file for reading and writing. The function must
return the actual file to open.

=cut
sub register_filename_callback
{
local ($mod, $func, $args) = @_;
push(@main::filename_callbacks, [ $mod, $func, $args ]);
}

=head2 register_command_callback(module|undef, &function, &args)

Registers some function to be called when the specified module (or all
modules) tries to execute a command. The function must return the actual
command to run.

=cut
sub register_command_callback
{
local ($mod, $func, $args) = @_;
push(@main::command_callbacks, [ $mod, $func, $args ]);
}

=head2 capture_function_output(&function, arg, ...)

Captures output that some function prints to STDOUT, and returns it

=cut
sub capture_function_output
{
local ($func, @args) = @_;
socketpair(SOCKET2, SOCKET1, AF_UNIX, SOCK_STREAM, PF_UNSPEC);
local $old = select(SOCKET1);
local @rv = &$func(@args);
select($old);
close(SOCKET1);
local $out;
local $_;
while(<SOCKET2>) {
	$out .= $_;
	}
close(SOCKET2);
return wantarray ? ($out, \@rv) : $out;
}

=head2 modules_chooser_button(field, multiple, [form])

Returns HTML for a button for selecting one or many Webmin modules

=cut
sub modules_chooser_button
{
return &theme_modules_chooser_button(@_)
	if (defined(&theme_modules_chooser_button));
local $form = defined($_[2]) ? $_[2] : 0;
local $w = $_[1] ? 700 : 500;
local $h = 200;
if ($_[1] && $gconfig{'db_sizemodules'}) {
	($w, $h) = split(/x/, $gconfig{'db_sizemodules'});
	}
elsif (!$_[1] && $gconfig{'db_sizemodule'}) {
	($w, $h) = split(/x/, $gconfig{'db_sizemodule'});
	}
return "<input type=button onClick='ifield = document.forms[$form].$_[0]; chooser = window.open(\"$gconfig{'webprefix'}/module_chooser.cgi?multi=$_[1]&module=\"+escape(ifield.value), \"chooser\", \"toolbar=no,menubar=no,scrollbars=yes,width=$w,height=$h\"); chooser.ifield = ifield; window.ifield = ifield' value=\"...\">\n";
}

=head2 substitute_template(text, &hash)

Given some text and a hash reference, for each ocurrance of $FOO or ${FOO} in
the text replaces it with the value of the hash key foo

=cut
sub substitute_template
{
# Add some extra fixed parameters to the hash
local %hash = %{$_[1]};
$hash{'hostname'} = &get_system_hostname();
$hash{'webmin_config'} = $config_directory;
$hash{'webmin_etc'} = $config_directory;
$hash{'module_config'} = $module_config_directory;
$hash{'webmin_var'} = $var_directory;

# Add time-based parameters, for use in DNS
$hash{'current_time'} = time();
local @tm = localtime($hash{'current_time'});
$hash{'current_year'} = $tm[5]+1900;
$hash{'current_month'} = sprintf("%2.2d", $tm[4]+1);
$hash{'current_day'} = sprintf("%2.2d", $tm[3]);
$hash{'current_hour'} = sprintf("%2.2d", $tm[2]);
$hash{'current_minute'} = sprintf("%2.2d", $tm[1]);
$hash{'current_second'} = sprintf("%2.2d", $tm[0]);

# Actually do the substition
local $rv = $_[0];
local $s;
foreach $s (keys %hash) {
	next if ($s eq '');	# Prevent just $ from being subbed
	local $us = uc($s);
	local $sv = $hash{$s};
	$rv =~ s/\$\{\Q$us\E\}/$sv/g;
	$rv =~ s/\$\Q$us\E/$sv/g;
	if ($sv) {
		# Replace ${IF}..${ELSE}..${ENDIF} block with first value,
		# and ${IF}..${ENDIF} with value
		$rv =~ s/\$\{IF-\Q$us\E\}(\n?)([\000-\377]*?)\$\{ELSE-\Q$us\E\}(\n?)([\000-\377]*?)\$\{ENDIF-\Q$us\E\}(\n?)/\2/g;
		$rv =~ s/\$\{IF-\Q$us\E\}(\n?)([\000-\377]*?)\$\{ENDIF-\Q$us\E\}(\n?)/\2/g;

		# Replace $IF..$ELSE..$ENDIF block with first value,
		# and $IF..$ENDIF with value
		$rv =~ s/\$IF-\Q$us\E(\n?)([\000-\377]*?)\$ELSE-\Q$us\E(\n?)([\000-\377]*?)\$ENDIF-\Q$us\E(\n?)/\2/g;
		$rv =~ s/\$IF-\Q$us\E(\n?)([\000-\377]*?)\$ENDIF-\Q$us\E(\n?)/\2/g;

		# Replace ${IFEQ}..${ENDIFEQ} block with first value if
		# matching, nothing if not
		$rv =~ s/\$\{IFEQ-\Q$us\E-\Q$sv\E\}(\n?)([\000-\377]*?)\$\{ENDIFEQ-\Q$us\E-\Q$sv\E\}(\n?)/\2/g;
		$rv =~ s/\$\{IFEQ-\Q$us\E-[^\}]+}(\n?)([\000-\377]*?)\$\{ENDIFEQ-\Q$us\E-[^\}]+\}(\n?)//g;

		# Replace $IFEQ..$ENDIFEQ block with first value if
		# matching, nothing if not
		$rv =~ s/\$IFEQ-\Q$us\E-\Q$sv\E(\n?)([\000-\377]*?)\$ENDIFEQ-\Q$us\E-\Q$sv\E(\n?)/\2/g;
		$rv =~ s/\$IFEQ-\Q$us\E-\S+(\n?)([\000-\377]*?)\$ENDIFEQ-\Q$us\E-\S+(\n?)//g;
		}
	else {
		# Replace ${IF}..${ELSE}..${ENDIF} block with second value,
		# and ${IF}..${ENDIF} with nothing
		$rv =~ s/\$\{IF-\Q$us\E\}(\n?)([\000-\377]*?)\$\{ELSE-\Q$us\E\}(\n?)([\000-\377]*?)\$\{ENDIF-\Q$us\E\}(\n?)/\4/g;
		$rv =~ s/\$\{IF-\Q$us\E\}(\n?)([\000-\377]*?)\$\{ENDIF-\Q$us\E\}(\n?)//g;

		# Replace $IF..$ELSE..$ENDIF block with second value,
		# and $IF..$ENDIF with nothing
		$rv =~ s/\$IF-\Q$us\E(\n?)([\000-\377]*?)\$ELSE-\Q$us\E(\n?)([\000-\377]*?)\$ENDIF-\Q$us\E(\n?)/\4/g;
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
disable module and features that are not appropriate, like filesystems/etc

=cut
sub running_in_zone
{
return 0 if ($gconfig{'os_type'} ne 'solaris' ||
	     $gconfig{'os_version'} < 10);
local $zn = `zonename 2>$null_file`;
chop($zn);
return $zn && $zn ne "global";
}

=head2 running_in_vserver

Returns 1 if the current Webmin instance is running in a Linux VServer.
Used to disable modules and features that are not appropriate

=cut
sub running_in_vserver
{
return 0 if ($gconfig{'os_type'} !~ /^\*-linux$/);
local $vserver;
open(MTAB, "/etc/mtab");
while(<MTAB>) {
	local ($dev, $mp) = split(/\s+/, $_);
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
at /proc/xen/capabilities

=cut
sub running_in_xen
{
return 0 if (!-r "/proc/xen/capabilities");
local $cap = &read_file_contents("/proc/xen/capabilities");
return $cap =~ /control_d/ ? 0 : 1;
}

=head2 list_categories(&modules)

Returns a hash mapping category codes to names

=cut
sub list_categories
{
local (%cats, %catnames);
&read_file("$config_directory/webmin.catnames", \%catnames);
foreach my $o (@lang_order_list) {
	&read_file("$config_directory/webmin.catnames.$o", \%catnames);
	}
local $m;
foreach $m (@{$_[0]}) {
	local $c = $m->{'category'};
	next if ($cats{$c});
	if (defined($catnames{$c})) {
		$cats{$c} = $catnames{$c};
		}
	elsif ($text{"category_$c"}) {
		$cats{$c} = $text{"category_$c"};
		}
	else {
		# try to get category name from module ..
		local %mtext = &load_language($m->{'dir'});
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
	local %gaccess = &get_module_acl(undef, "");
	$main::readonly_mode_cache = $gaccess{'readonly'} ? 1 : 0;
	}
return $main::readonly_mode_cache;
}

=head2 command_as_user(user, with-env?, command, ...)

Returns a command to execute some command as the given user

=cut
sub command_as_user
{
local ($user, $env, $cmd, @args) = @_;
if ($gconfig{'os_type'} =~ /-linux$/) {
	# In case user doesn't have a valid shell
	local @uinfo = getpwnam($user);
	if ($uinfo[8] ne "/bin/sh" && $uinfo[8] !~ /\/bash$/) {
		$shellarg = " -s /bin/sh";
		}
	}
local $rv = "su".($env ? " -" : "").$shellarg.
	    " ".quotemeta($user)." -c ".quotemeta(join(" ", $cmd, @args));
return $rv;
}

$osdn_download_host = "prdownloads.sourceforge.net";
$osdn_download_port = 80;

=head2 list_osdn_mirrors(project, file)

Given a OSDN project and filename, returns a list of mirror URLs from
which it can be downloaded

=cut
sub list_osdn_mirrors
{
local ($project, $file) = @_;
local ($page, $error, @rv);
&http_download($osdn_download_host, $osdn_download_port,
	       "/project/mirror_picker.php?groupname=".&urlize($project).
		"&filename=".&urlize($file),
	       \$page, \$error, undef, 0, undef, undef, 0, 0, 1,
	       \%headers);
while($page =~ /<input[^>]*name="use_mirror"\s+value="(\S+)"[^>]*>([^,]+),\s*([^<]*)<([\000-\377]*)/i) {
	# Got a country and city
	push(@rv, { 'country' => $3,
		    'city' => $2,
		    'mirror' => $1,
		    'url' => "http://$1.dl.sourceforge.net/sourceforge/$project/$file" });
	$page = $4;
	}
if (!@rv) {
	# None found! Try some known mirrors
	foreach my $m ("superb-east", "superb-west", "osdn") {
		local $url = "http://$m.dl.sourceforge.net".
			     "/sourceforge/$project/$file";
		local ($host, $port, $page, $ssl) = &parse_http_url($url);
		local $h = &make_http_connection(
			$host, $port, $ssl, "HEAD", $page);
		next if (!ref($h));

		# Make a HEAD request
		&write_http_connection($h, "Host: $host\r\n");
		&write_http_connection($h, "User-agent: Webmin\r\n");
		&write_http_connection($h, "\r\n");
		$line = &read_http_connection($h);
		$line =~ s/\r|\n//g;
		&close_http_connection($h);
		if ($line =~ /^HTTP\/1\..\s+(200)\s+/) {
			push(@rv, { 'mirror' => $m,
				    'default' => $m eq 'osdn',
				    'url' => $url });
			last;
			}
		}
	}
return @rv;
}

=head2 convert_osdn_url(url)

Given a URL like http://osdn.dl.sourceforge.net/sourceforge/project/file.zip
or http://prdownloads.sourceforge.net/project/file.zip , convert it
to a real URL on the best mirror.

=cut
sub convert_osdn_url
{
local ($url) = @_;
if ($url =~ /^http:\/\/[^\.]+.dl.sourceforge.net\/sourceforge\/([^\/]+)\/(.*)$/ ||
    $url =~ /^http:\/\/prdownloads.sourceforge.net\/([^\/]+)\/(.*)$/) {
	# Find best site
	local ($project, $file) = ($1, $2);
	local @mirrors = &list_osdn_mirrors($project, $file);
	local $site;
	local $pref = $gconfig{'osdn_mirror'} || "unc";
	($site) = grep { $_->{'mirror'} eq $pref } @mirrors;
	$site ||= $mirrors[0];
	return wantarray ? ( $site->{'url'}, $site->{'default'} )
			 : $site->{'url'};
	}
else {
	# Some other source .. don't change
	return wantarray ? ( $url, 2 ) : $url;
	}
}

=head2 get_current_dir

Returns the directory the current process is running in

=cut
sub get_current_dir
{
local $out;
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
su , getpw* and so on

=cut
sub supports_users
{
return $gconfig{'os_type'} ne 'windows';
}

=head2 supports_symlinks

Returns 1 if the current OS supports symbolic and hard links

=cut
sub supports_symlinks
{
return $gconfig{'os_type'} ne 'windows';
}

=head2 quote_path(path)

Returns a path with safe quoting for the operating system

=cut
sub quote_path
{
local ($path) = @_;
if ($gconfig{'os_type'} eq 'windows' || $path =~ /^[a-z]:/i) {
	# Windows only supports "" style quoting
	return "\"$path\"";
	}
else {
	return quotemeta($path);
	}
}

=head2 get_windows_root

Returns the base windows system directory, like c:/windows

=cut
sub get_windows_root
{
if ($ENV{'SystemRoot'}) {
	local $rv = $ENV{'SystemRoot'};
	$rv =~ s/\\/\//g;
	return $rv;
	}
else {
	return -d "c:/windows" ? "c:/windows" : "c:/winnt";
	}
}

=head2 read_file_contents(file)

Given a filename, returns its complete contents as a string

=cut
sub read_file_contents
{
&open_readfile(FILE, $_[0]) || return undef;
local $/ = undef;
local $rv = <FILE>;
close(FILE);
return $rv;
}

=head2 unix_crypt(password, salt)

Performs Unix encryption on a password, using crypt() or Crypt::UnixCrypt

=cut
sub unix_crypt
{
local ($pass, $salt) = @_;
return "" if (!$salt);   # same as real crypt
local $rv = eval "crypt(\$pass, \$salt)";
local $err = $@;
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

Given a string like  foo "bar baz" quux
returns the array foo, bar baz, quux

=cut
sub split_quoted_string
{
local $str = $_[0];
local @rv;
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
clearing out old data

=cut
sub write_to_http_cache
{
local ($url, $file) = @_;
return 0 if (!$gconfig{'cache_size'});

# Don't cache downloads that look dynamic
if ($url =~ /cgi-bin/ || $url =~ /\?/) {
	return 0;
	}

# Check if the current module should do caching
if ($gconfig{'cache_mods'} =~ /^\!(.*)$/) {
	# Caching all except some modules
	local @mods = split(/\s+/, $1);
	return 0 if (&indexof($module_name, @mods) != -1);
	}
elsif ($gconfig{'cache_mods'}) {
	# Only caching some modules
	local @mods = split(/\s+/, $gconfig{'cache_mods'});
	return 0 if (&indexof($module_name, @mods) == -1);
	}

# Work out the size
local $size;
if (ref($file)) {
	$size = length($$file);
	}
else {
	local @st = stat($file);
	$size = $st[7];
	}

if ($size > $gconfig{'cache_size'}) {
	# Bigger than the whole cache - so don't save it
	return 0;
	}
local $cfile = $url;
$cfile =~ s/\//_/g;
$cfile = "$main::http_cache_directory/$cfile";

# See how much we have cached currently, clearing old files
local $total = 0;
mkdir($main::http_cache_directory, 0700) if (!-d $main::http_cache_directory);
opendir(CACHEDIR, $main::http_cache_directory);
foreach my $f (readdir(CACHEDIR)) {
	next if ($f eq "." || $f eq "..");
	local $path = "$main::http_cache_directory/$f";
	local @st = stat($path);
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
	local ($ok, $err) = &copy_source_dest($file, $cfile);
	}

return 1;
}

=head2 check_in_http_cache(url)

If some URL is in the cache and valid, return the filename for it

=cut
sub check_in_http_cache
{
local ($url) = @_;
return undef if (!$gconfig{'cache_size'});

# Check if the current module should do caching
if ($gconfig{'cache_mods'} =~ /^\!(.*)$/) {
	# Caching all except some modules
	local @mods = split(/\s+/, $1);
	return 0 if (&indexof($module_name, @mods) != -1);
	}
elsif ($gconfig{'cache_mods'}) {
	# Only caching some modules
	local @mods = split(/\s+/, $gconfig{'cache_mods'});
	return 0 if (&indexof($module_name, @mods) == -1);
	}

local $cfile = $url;
$cfile =~ s/\//_/g;
$cfile = "$main::http_cache_directory/$cfile";
local @st = stat($cfile);
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

Returns 1 if the current browser is assumed to support javascript

=cut
sub supports_javascript
{
if (defined(&theme_supports_javascript)) {
	return &theme_supports_javascript();
	}
return $ENV{'MOBILE_DEVICE'} ? 0 : 1;
}

$done_web_lib_funcs = 1;

1;
