#!/usr/local/bin/perl
# Refresh the list of visible modules

require './webmin-lib.pl';
&ReadParse();

&ui_print_unbuffered_header(undef, $text{'refreshmods_title'}, "", undef, 0, 1);

# Re-run install checks
&flush_webmin_caches();
print $text{'refreshmods_installed'},"<br>\n";
($installed, $changed) = &build_installed_modules(1);
@not = grep { $installed->{$_} eq '0' } (keys %$installed);
@got = grep { $installed->{$_} ne '0' } (keys %$installed);
print &text('refeshmods_counts', scalar(@not), scalar(@got)),"\n";

# Refresh left frame, if possible
if (@$changed && defined(&theme_post_change_modules)) {
	&theme_post_change_modules();
	}

&ui_print_footer();
