#!/usr/local/bin/perl
#/usr/local/bin/SecureMyEmail/Eighteen/eighteen_alert.pl
# Created on 11 May, 2009
# Last modified on: 13 Jan, 2010
# Copyright 2009 - Arapaut V Sivaprasad and WebGenie Software Pty Ltd.
#--------------------------------------
#Purpose: Alert the quarantined mails
#Runs with 600 sec sleep
#Checks the quarantine tray for mails held with notify=1 flag
#Check the user's setting to determine whether to be alerted in the current cycle
#This is calculated by checking the users 'users|alertFrequency' value 
#which is a multiple of 10 min
#--------------------------------------
require "./eighteen_common.pl";
use DBI;
sub MailTheNotification
{
	open (INP, "<$mailtemplate_in_template");
	my @filecontent = <INP>;
	close (INP);
	my $len = $#filecontent;
	$mailbody = "";
	for (my $j=0; $j <= $len; $j++)
	{
		$mailbody .= &WSCPReplaceTags($filecontent[$j]);
	}
	$Form_subject_user = "EM_alert: $k : $subject";
#	&PutHeadersInAckMailFile ($senderEmail, $Enquiry_email, $Enquiry_email, $Enquiry_email, $Alert_email, $Form_subject_user);
	&PutHeadersInAckMailFile ($Owner_name, $Owner_email, "", "", $Alert_email, $Form_subject_user);
    $tfilecontent .= "\n--------------The Following is in HTML Format\n";
    $tfilecontent .= "Content-Type: text/html; charset=us-ascii\n";
    $tfilecontent .= "Content-Transfer-Encoding: 7bit\n\n";
    $tfilecontent .= "<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.0 Transitional//EN\">\n";
	$tfilecontent .= $mailbody;
    $tfilecontent .= "\n--------------The Following is in HTML Format--\n";
	my $filename = "$tmpDir/sme_$$.tmp";
	open (OUT, ">$filename");
	print OUT $tfilecontent;
	close (OUT);
	if ($Alert_email =~ /.*\@.*\./ && $Alert_email !~ /;/ && $Alert_email !~ /\s/)
	{
		`$mailprogram -f $Owner_email $Alert_email < $filename`;
		$mailerror = $?;
	}
#	$k =0;
}
sub ToBeAlerted
{
	$query = "select alertFrequency from `users` where (Clean_email='$Alert_email' or Raw_email='$Alert_email')";
	&execute_query($query);
	my @results = &Fetchrow_array(1);
	$alertFrequency = $results[0];
#print "query = $query\n";	
#print "alertFrequency = $alertFrequency\n";
if (!$alertFrequency)
{
	return 0;
}
	$holdAlert = $thisCycle%$alertFrequency;
	if (!$holdAlert)
	{
		return 1;
	}
	else
	{
		return 0;
	}
}
sub CheckGmailPassedMails
{
	$newmailDir   = "$qmailDir/$wg_domain/$wg_mbox/Maildir/new";
	$curmailDir   = "$qmailDir/$wg_domain/$wg_mbox/Maildir/cur";
	$tmpmailDir   = "$qmailDir/$wg_domain/$wg_mbox/Maildir/tmp";

	opendir (DIR, "$newmailDir");
	@inputRecords = readdir (DIR);
	closedir (DIR);
	my $len = $#inputRecords;
	if ($len > 1)
	{
		`mv $newmailDir/* $tmpmailDir`;  # Move from 'new' to 'tmp'
	}
	opendir (DIR, "$curmailDir");
	@inputRecords = readdir (DIR);
	closedir (DIR);
	my $len = $#inputRecords;
	if ($len > 1)
	{
		`mv $curmailDir/* $tmpmailDir`;  # Move from 'cur' to 'tmp'
	}
	opendir (DIR, "$tmpmailDir");
	@inputRecords = readdir (DIR);
	closedir (DIR);
	my $len = $#inputRecords;
#print "tmpmailDir = $tmpmailDir; len = $len\n";	
	if ($len > 1)
	{
		for ($j=0; $j <= $len; $j++) # 0 and 1 are . and ..
		{
			$mailfile = "$tmpmailDir/$inputRecords[$j]";
			if (-f $mailfile)
			{
				&GetsenderEmailAndIP('alert_pl:CheckGmailPassedMails'); # This gets the $Message_ID as well
				`rm $mailfile`; # Delete this file from /tmp. Put this line here so that if the program crashes after this point, the mail will not be left dangling
				$query = "select lmode,challenge,urk,userUrk,senderEmail,alert from `quarantine` where Message_ID = '$Message_ID' and delivered = 0";
				&execute_query($query);
				@results = &Fetchrow_array(6);
				my $len = $#results;
print "1. len=$len;  query = $query\n";
				if ($len < 0)
				{
					# This means the $Message_ID is not in the DB. Maybe it had a null Message_ID previously. So, recreate it
					$Message_ID = "<" . $senderEmail . "_" . $subject . ">";
					$query = "select lmode,challenge,urk,userUrk,senderEmail,alert from `quarantine` where Message_ID = '$Message_ID' and delivered = 0";
					&execute_query($query);
					@results = &Fetchrow_array(6);
					my $len = $#results;
print "2. len=$len;  query = $query\n";
				}

				$lmode = $results[0];
				$challenge = $results[1];
				$urk = $results[2]; $msgID = $urk;
				$userUrk = $results[3];
				$senderEmail = $results[4];
				$alert = $results[5];
				$notignored = &CheckIgnoredList('CheckGmailPassedMails');
print "notignored = $notignored\n";

				if ($notignored > 0 && ($lmode || (!$alert && !$challenge))) # If in learn mode or BOTH alert and CR are turned off, the mail must be delivered
				{
					#Deliver the mail if lmode =1. No Alert or challenge
					$query = "update quarantine set delivered=1 where Message_ID = '$Message_ID' and delivered = 0";
print "3. query = $query\n";
					&execute_query($query);
				}
				else
				{
					if ($alert && $notignored > 0)
					{
						&IncrementNotified; # This increments the notified value
						# If lmode = 0, send the Alert. Then, if challenge=1, send challenge
						$query = "update `statistics` set alrt=alrt+1 where userUrk=$userUrk and day=0";
print "4. query = $query\n";
						&execute_query($query);
						# Set the flag to send alert. To make sure that only one alert is sent, even in cases of repeated settings, set the notified=1 only itf it is zero.
						$query = "update quarantine set notified=1 where Message_ID = '$Message_ID' and notified=0 and delivered = 0"; 
print "5. query = $query\n";
						&execute_query($query);
#						`rm $mailfile`; # Keep it here so that if the update does not happen, it will be tried at next round
&RecordLogs("Setting Alert\n");
print "Setting Alert\n";
						# Note: There is some error when called from crontab. The update 'history' is happening, but doesn't return from the sub. Shell execution of this script does not have the error.
						# Hence, putting this call after the updating of 'quarantine'
						&UpdateHistoryTable($alertedcode); 
					}
					if ($challenge)
					{
						$query = "update `statistics` set cr=cr+1 where userUrk=$userUrk and day=0";
#print "6. query = $query\n";
						&execute_query($query);
						if ($senderEmail !~ /^$gmailCleanAddress$/i)
						{
							# Send the CR only if the sender is not the same as the address where Gmail forwards clean mails. Otherwise it may result in a loop, though not likely 
							&SendChallenge;
#							`rm $mailfile`; # Keep it here so that if the update does not happen, it will be tried at next round
						}
						&UpdateHistoryTable($challengedcode);
					}
				}
			}
		}
	}
}

sub CheckQuarantine
{
	$query = "select urk,hashcode,senderEmail,recipientEmail,clean_email,sascore,subject,threelines,ip from `quarantine` where notified=1 order by clean_email";
	&execute_query($query);
	my @results = &Fetchrow_array(9);
	my $len = $#results;
#&RecordLogs("query = $query; len = $len\n");				
	$prev_clean_email = $results[4];  # This is used to send the mail to the correct address
	$messages = "";
	$k = 0;
	for (my $j=0; $j <= $len; $j++)
	{
		$urk = $results[$j++]; $msgID = $urk;
#		&UpdateHistoryTable($alertedcode);
		$hashcode = $results[$j++];
		$senderEmail = $results[$j++];
		$recipientEmail = $results[$j++];
			$recipientEmail =~ s/\,/, /gi;
		$Clean_email = $results[$j++];
		$sascore = $results[$j++];
		$subject = $results[$j++];
		$threelines = $results[$j++];
		$senderIP = $results[$j];
		if ($prev_clean_email ne $Clean_email)
		{
			$Alert_email = $prev_clean_email;
			$prev_clean_email =  $Clean_email;
			$toBeAlerted = &ToBeAlerted;
			if ($toBeAlerted)
			{
&RecordLogs("1. Sending Alert to $Alert_email\n");
				$noalert_sent = 1; # Make sure that the alert is ent only to avs
				&MailTheNotification;  # Send the alert only if there is any to be alerted
#				$query = "update `quarantine` set notified=2 where notified=1";
#				&execute_query($query);
				$messages = "";
			}
		}
#		$dont_alert = &CheckBannedDetails; # Dont include if from Russia, etc.
#		if ($dont_alert > 0) 
#		{ 
#			$query = "update `quarantine` set notified=-1 where urk='$urk'"; # sent_to_clean=1 means not alerted due to banned characteristics
#			&execute_query($query);
#			next; 
#		}
		$k++;
		$messages .= "<tr><td class=\"lines\">$k. <a href=\"$baseURL$cgiURL?A+$hashcode\" Title=\"Testing\">Accept</a> | <a href=\"$baseURL$cgiURL?B+$hashcode\">Block</a> | <a href=\"$baseURL$cgiURL?U+$hashcode\">Un-block</a></td><td class=\"lines\">$senderEmail</td><td class=\"lines\">$recipientEmail</td><td class=\"lines\">$subject<br>[$threelines]</td></tr>\n";
		$query = "update `quarantine` set notified=2 where urk='$urk'";
		&execute_query($query);
	}
	if ($len >= 0 && !$noalert_sent)
	{
		$Alert_email = $prev_clean_email;
		$toBeAlerted = &ToBeAlerted;
		if ($toBeAlerted)
		{
&RecordLogs("2. Sending Alert to $Alert_email\n");				
			&MailTheNotification;  # Send the alert only if there is any to be alerted
#			$query = "update `quarantine` set alrt_sent=1,notified=2 where notified=1";
#			&execute_query($query);
			$messages = "";
		}
	}
}

#-------------------------------------------------------------------------------
# Main body of the script
sub do_main
{
#	$onceonly = $ARGV[0];
#	$thisCycle = 0;
	$monitorcycle = 0;  # This will update `monitor` at start
#	while (1)
#	{
		&ConnectToDBase;
		&CheckGmailPassedMails; # This will check the folder where mails sent to Gmail have come back as clean and set their alert as notified = 1.. Replaces the corn job 'eighteen_check_cleang_mail.pl'
		&CheckQuarantine; # This checks and sends the Alerts  
		if ($onceonly) { last; }
		$thisCycle++;
		if ($thisCycle > 86400) { $thisCycle = 0; } # Max 1 day for alert frequency
		&UpdateMonitorTable("al");
		$dbh->disconnect;
#		sleep (10); # Minimum time for instant alerts. Give users to set only in multiples of 10 sec
#	}
}
$|=1;
&do_main;

