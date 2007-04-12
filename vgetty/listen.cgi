#!/usr/local/bin/perl
# listen.cgi
# Convert an RMD file to WAV format

require './vgetty-lib.pl';
&ReadParse();
@conf = &get_config();
$dir = $in{'mode'} ? &messages_dir(\@conf) : &receive_dir(\@conf);
$in{'file'} =~ /\.\./ && &error($text{'listen_efile'});
$path = "$dir/$in{'file'}";
-r $path || &error($text{'listen_epath'});
print "Content-type: audio/wav\n\n";
$esc = quotemeta($path);
open(OUT, "rmdtopvf $esc 2>/dev/null | pvftowav 2>/dev/null |");
while(read(OUT, $buf, 1024)) {
	print $buf;
	}
close(OUT);

