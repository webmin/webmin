#!/usr/local/bin/perl

require './filemin-lib.pl';
&ReadParse();

get_paths();

my $file = &simplify_path($cwd . '/' . $in{'file'});
&check_allowed_path($file);
my $data = &ui_read_file_contents_limit(
            { 'file', $file,
              'limit', $in{'limit'},
              'reverse', $in{'reverse'},
              'head', $in{'head'},
              'tail', $in{'tail'}
            });
my $encoding_name;
eval "use Encode::Detect::Detector;";
if (!$@) {
    $encoding_name = Encode::Detect::Detector::detect($data);
}
if ($userconfig{'config_portable_module_filemanager_editor_detect_encoding'} ne 'false') {
    my $forced = ($data =~ /(.*\n)(.*\n)(.*\n)/);
    $forced = (($1 . $2 . $3) =~ /coding[=:]\s*([-\w.]+)/);
    if ((lc(get_charset()) eq "utf-8" && ($encoding_name && lc($encoding_name) ne "utf-8")) || $forced) {
        if ($forced) {
            $encoding_name = "$1";
        }
        eval {$data = Encode::encode('utf-8', Encode::decode($encoding_name, $data))};
    }
}

my $file_binary = -s $file >= 128 && -B $file;
my %tinfo = &get_theme_info($current_theme);
&ui_print_header(undef, $text{'edit_file'}, "");
print "<style>textarea {padding: 4px;}</style>"
    if (!$tinfo{'bootstrap'});
print &ui_table_start(&html_escape("$path/$in{'file'}"), "width=100%;", 1);
print &ui_form_start("save_file.cgi", "post", undef, "data-encoding=\"$encoding_name\" data-binary=\"$file_binary\"");
print &ui_hidden("file", $in{'file'}), "\n";
print &ui_hidden("encoding", $encoding_name), "\n";
print &ui_textarea("data", $data, 30, undef, undef, undef, " style='width: 100%' id='data'");
print &ui_hidden("path", $path);
print &ui_form_end([[save, $text{'save'}], [save_close, $text{'save_close'}]]);
print &ui_table_end();
&ui_print_footer("index.cgi?path=" . &urlize($path), $text{'previous_page'});
