<div id="toolbar">
<script type="text/javascript">
	//<![CDATA[

	// prepare DOM for YUI Toolbar

	 $(document).ready(function() {
	    $("#editmenuc").empty();
	    $("#duplicate").parent().remove();
		$("#delete").parent().remove();
	 	$("#renewc").empty();
	    yuiToolbar();
	 });

	// YUI Toolbar Functions

	function yuiToolbar() {
	
	new YAHOO.widget.Button("new_periodical");
    new YAHOO.widget.Button("delete_periodical");
    new YAHOO.widget.Button("delete_periodical_serial");
    new YAHOO.widget.Button("delete_subscription");
    new YAHOO.widget.Button("delete_subscription_serial");
    new YAHOO.widget.Button("renew");
    new YAHOO.widget.Button("receive");
	}

	//]]>
	</script>
<ul class="toolbar">
	<TMPL_IF NAME="CAN_user_serials_periodical_create"><li><a id="new_periodical" href="periodicals-add.pl">New Periodical</a></li></TMPL_IF>

<!--
    <TMPL_IF NAME="periodical_id">
	<li><a id="delete_periodical" href="delete.pl?type=periodical&id=<TMPL_VAR NAME="periodical_id">">Delete Periodical</a></li>
    </TMPL_IF>

    <TMPL_IF NAME="subscription_serial_id">
	<li><a id="delete_subscription_serial" href="delete.pl?type=subscription_serial&id=<TMPL_VAR NAME="subscription_serial_id">">Delete Subscription Serial</a></li>
    </TMPL_IF>

    <TMPL_IF NAME="subscription_id">
	<li><a id="delete_subscription" href="delete.pl?type=subscription&id=<TMPL_VAR NAME="subscription_id">">Delete Subscription</a></li>
    </TMPL_IF>
-->

    <!-- TMPL_IF NAME="subscriptionid" -->
        <!-- TMPL_UNLESS name="cannotedit" -->
            <li id="editmenuc"><a id="edit" href="/cgi-bin/koha/serials/subscription-add.pl?op=mod&amp;subscriptionid=<!-- TMPL_VAR name="subscriptionid" -->">Edit</a></li>
        <!-- /TMPL_UNLESS -->
        <li><a id="duplicate" href="/cgi-bin/koha/serials/subscription-add.pl?op=dup&amp;subscriptionid=<!-- TMPL_VAR name="subscriptionid" -->">Duplicate </a></li>
        <!-- TMPL_UNLESS name="cannotedit" -->
            <li id="renewc"><a id="renew" href="#" onclick="popup(<!--TMPL_VAR Name="subscriptionid"-->)">Renew </a></li>
            <li><a id="receive" href="/cgi-bin/koha/serials/serials-edit.pl?subscriptionid=<!-- TMPL_VAR name="subscriptionid" -->&amp;serstatus=1,3">Receive</a></li>
            <li><a id="delete" href="javascript:confirm_deletion()">Delete</a></li>
        <!-- /TMPL_UNLESS -->
    <!-- /TMPL_IF -->
</ul>
</div>
