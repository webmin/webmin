#!/usr/local/bin/perl
# save_files.cgi
# Save some kind of per-files options

require './apache-lib.pl';
&ReadParse();
$access{'global'} || &error($text{'htaccess_ecannot'});
$access_types{$in{'type'}} || &error($text{'etype'});
&allowed_auth_file($in{'file'}) || &error($text{'htindex_ecannot'});
$hconf = &get_htaccess_config($in{'file'});
$d = $hconf->[$in{'idx'}];
$conf = $d->{'members'};
@edit = &editable_directives($in{'type'}, 'directory');

&lock_file($in{'file'});
&error_setup(&text('efailed', $text{"type_$in{'type'}"}));
&parse_inputs(\@edit, $conf, $hconf);
&unlock_file($in{'file'});
&webmin_log("files", $in{'type'}, "$in{'file'}:$d->{'words'}->[0]", \%in);

&redirect("files_index.cgi?file=".&urlize($in{'file'})."&idx=$in{'idx'}");
