=head1 web-lib.pl

This file must be included by all Webmin CGI scripts, either directly or via
another module-specific .pl file. For example :

 do '../web-lib.pl';
 init_config();
 do '../ui-lib.pl';
 ui_print_header(undef, 'My Module', '');

This file in turn includes web-lib-funcs.pl, which is where the majority of
the Webmin API functions are defined.

=cut

$remote_error_handler = "error";
@INC = &unique(@INC, ".");
%month_to_number_map = ( 'jan' => 0, 'feb' => 1, 'mar' => 2, 'apr' => 3,
                	 'may' => 4, 'jun' => 5, 'jul' => 6, 'aug' => 7,
                	 'sep' => 8, 'oct' => 9, 'nov' =>10, 'dec' =>11 );
%number_to_month_map = reverse(%month_to_number_map);
$main::initial_process_id ||= $$;
$main::http_cache_directory = $ENV{'WEBMIN_VAR'}."/cache";
$main::default_debug_log_size = 10*1024*1024;
$main::default_debug_log_file = $ENV{'WEBMIN_VAR'}."/webmin.debug";

$webmin_feedback_address = "feedback\@webmin.com";
$default_lang = "en";
$default_charset = "iso-8859-1";
$osdn_download_host = "prdownloads.sourceforge.net";
$osdn_download_port = 80;

=head2 unique(string, ...)

Returns the unique elements of some array, passed as its parameters.

=cut
sub unique
{
my (%found, @rv);
foreach my $e (@_) {
	if (!$found{$e}++) { push(@rv, $e); }
	}
return @rv;
}

if (!$done_web_lib_funcs) {
	my $script = -r '../web-lib-funcs.pl' ? '../web-lib-funcs.pl'
						 : 'web-lib-funcs.pl';
	do $script;
	}

1;

