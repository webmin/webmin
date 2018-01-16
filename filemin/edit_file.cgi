#!/usr/local/bin/perl

require './filemin-lib.pl';
&ReadParse();

get_paths();

my $file = &simplify_path($cwd . '/' . $in{'file'});
&check_allowed_path($file);
my $data = &read_file_contents($file);

my $encoding_name;
eval "use Encode::Detect::Detector;";
if (!$@) {
    $encoding_name = Encode::Detect::Detector::detect($data);
}
my $forced = ($data =~ /(.*\n)(.*\n)(.*\n)/);
$forced = (($1 . $2 . $3) =~ /coding[=:]\s*([-\w.]+)/);
if ((lc(get_charset()) eq "utf-8" && ($encoding_name && lc($encoding_name) ne "utf-8")) || $forced) {
    if ($forced) {
        $encoding_name = "$1";
    }
    use Encode qw( encode decode );
    eval {$data = Encode::encode('utf-8', Encode::decode($encoding_name, $data))};
}

&ui_print_header(undef, $text{'edit_file'}, "");
$head = "<link rel='stylesheet' type='text/css' href='unauthenticated/css/style.css' />";

if ($current_theme ne 'authentic-theme') {
    $head .= "<script type='text/javascript' src='unauthenticated/jquery/jquery.min.js'></script>";
    $head .= "<script type='text/javascript' src='unauthenticated/jquery/jquery-ui.min.js'></script>";
    $head .= "<link rel='stylesheet' type='text/css' href='unauthenticated/jquery/jquery-ui.min.css' />";

    # Include Codemirror specific files
    $head .= "<link rel='stylesheet' href='unauthenticated/js/lib/codemirror/lib/codemirror.css' />";
    $head .= "<script src='unauthenticated/js/lib/codemirror/lib/codemirror.js'></script>";
    $head .= "<script src='unauthenticated/js/lib/codemirror/addon/mode/loadmode.js'></script>";
    $head .= "<script src='unauthenticated/js/lib/codemirror/mode/meta.js'></script>";
    $head .= "<script src='unauthenticated/js/lib/codemirror/mode/javascript/javascript.js'></script>";
    $head .= "<script src='unauthenticated/js/lib/codemirror/mode/scheme/scheme.js'></script>";
    $head .= "<style type='text/css'>.CodeMirror {height: auto;}</style>";
}

print $head;

print ui_table_start(&html_escape("$path/$in{'file'}"), undef, 1);

print &ui_form_start("save_file.cgi", "post", undef, "data-encoding=\"$encoding_name\"");
print &ui_hidden("file", $in{'file'}), "\n";
print &ui_hidden("encoding", $encoding_name), "\n";
print &ui_textarea("data", $data, 20, 80, undef, undef, "style='width: 100%' id='data'");
print &ui_hidden("path", $path);
print &ui_form_end([[save, $text{'save'}], [save_close, $text{'save_close'}]]);

print ui_table_end();

print "<script type='text/javascript' src='unauthenticated/js/cmauto.js'></script>";
print "<script type='text/javascript'>\$(document).ready( function() { change('" . $in{'file'} . "'); });</script>";

&ui_print_footer("index.cgi?path=" . &urlize($path), $text{'previous_page'});
