#!/usr/bin/perl

require './filemin-lib.pl';
&ReadParse();

get_paths();

$data = &read_file_contents($cwd.'/'.$in{file});

&ui_print_header(undef, $text{'edit_file'}, "");
$head = "<link rel='stylesheet' type='text/css' href='unauthenticated/css/style.css' />";

if ($current_theme ne 'authentic-theme') {
    $head.= "<script type='text/javascript' src='unauthenticated/jquery/jquery.min.js'></script>";
    $head.= "<script type='text/javascript' src='unauthenticated/jquery/jquery-ui.min.js'></script>";
    $head.= "<link rel='stylesheet' type='text/css' href='unauthenticated/jquery/jquery-ui.min.css' />";

    # Include Codemirror specific files
    $head.= "<link rel='stylesheet' href='unauthenticated/js/lib/codemirror/lib/codemirror.css' />";
    $head.= "<script src='unauthenticated/js/lib/codemirror/lib/codemirror.js'></script>";
    $head.= "<script src='unauthenticated/js/lib/codemirror/addon/mode/loadmode.js'></script>";
    $head.= "<script src='unauthenticated/js/lib/codemirror/mode/meta.js'></script>";
    $head.= "<script src='unauthenticated/js/lib/codemirror/mode/javascript/javascript.js'></script>";
    $head.= "<script src='unauthenticated/js/lib/codemirror/mode/scheme/scheme.js'></script>";
    $head.= "<style type='text/css'>.CodeMirror {height: auto;}</style>";
}

print $head;

print ui_table_start("$path/$in{'file'}", undef, 1);

print &ui_form_start("save_file.cgi", "post");
print &ui_hidden("file", $in{'file'}),"\n";
print &ui_textarea("data", $data, 20, 80, undef, undef, "style='width: 100%' id='data'");
print &ui_hidden("path", $path);
print &ui_form_end([ [ save, $text{'save'} ], [ save_close, $text{'save_close'} ] ]);

print ui_table_end();

print "<script type='text/javascript' src='unauthenticated/js/cmauto.js'></script>";
print "<script type='text/javascript'>\$(document).ready( function() { change('".$in{'file'}."'); });</script>";

&ui_print_footer("index.cgi?path=$path", $text{'previous_page'});
