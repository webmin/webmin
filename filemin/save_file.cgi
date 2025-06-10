#!/usr/local/bin/perl

require './filemin-lib.pl';
&ReadParse();

get_paths();

my @errors;

# Validate inputs
my $file = &simplify_path($cwd.'/'.$in{'file'});
&check_allowed_path($file);
&error($text{'error_saving_file'}." : ".ucfirst($text{'error_write'}))
    if (!can_write($file));
$data = $in{'data'};
$data =~ s/\r\n/\n/g;

if ( $in{'encoding'} && lc( $in{'encoding'} ) ne "utf-8" ) {
    eval { $data = Encode::encode( $in{'encoding'}, Encode::decode( 'utf-8', $data ) ) };
}
&open_tempfile(SAVE, ">$file") ||
	&error($text{'error_saving_file'}." : ".&html_escape("$!"));
&print_tempfile(SAVE, $data);
&close_tempfile(SAVE);

if ($in{'save_close'}) {
    &redirect("index.cgi?path=".&urlize($path));
} else {
    &redirect("edit_file.cgi?path=".&urlize($path).
	      "&file=".&urlize($in{'file'}));
}
