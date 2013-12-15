#!/usr/local/bin/perl
# lang.cgi
# Return language translation values

require './file-lib.pl';

&print_content_type();

if (&get_charset() eq $default_charset) {
	# Convert any HTML entities to their 'real' single-byte forms,
	# as we are using the iso-8859-1 character set.
	foreach $k (keys %text) {
		print $k,"=",&entities_to_ascii($text{$k}),"\n";
		}
	}
elsif (&get_charset() eq 'UTF-8') {
	# Convert any HTML entities to UTF-8 to match the output charset
	eval "use Encode";
	foreach $k (keys %text) {
		$str = $text{$k};
		if ($str =~ /&#(\d+);|&([a-z]+);/) {
			$str = Encode::encode('utf-8',
				&entities_to_ascii($str));
			}
                print $k,"=",$str,"\n";
                }
	}
else {
	# Don't do HTML entity conversion for other character sets
	foreach $k (keys %text) {
		print $k,"=",$text{$k},"\n";
		}
	}
