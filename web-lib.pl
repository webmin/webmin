
@INC = &unique(@INC, ".");
%month_to_number_map = ( 'jan' => 0, 'feb' => 1, 'mar' => 2, 'apr' => 3,
                	 'may' => 4, 'jun' => 5, 'jul' => 6, 'aug' => 7,
                	 'sep' => 8, 'oct' => 9, 'nov' =>10, 'dec' =>11 );
%number_to_month_map = reverse(%month_to_number_map);
$main::default_debug_log_size = 10*1024*1024;

$webmin_feedback_address = "feedback\@webmin.com";
$default_lang = "en";
$default_charset = "iso-8859-1";

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

# Has to be set after error is defined
$remote_error_handler ||= \&error;
$main::remote_error_handler ||= \&error;

1;

