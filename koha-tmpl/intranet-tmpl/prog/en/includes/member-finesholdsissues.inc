<script type="text/javascript">
$(document).ready(function() {
	$('#finesholdsissues > ul').tabs();
	$.tablesorter.defaults.widgets = ['zebra'];
	$("#issuest").tablesorter({<!-- TMPL_IF NAME="dateformat_metric" -->
		dateFormat: 'uk',<!-- /TMPL_IF -->
		headers: { 1: { sorter: 'articles' },5: { sorter: false },6:{sorter:false},7:{sorter:false},8:{sorter:false}}
	}); 
	$("#holdst").tablesorter({
		sortList: [[1,0]],
		headers: { 9: {sorter: false}, 10: {sorter: false} }
	}); 
    <!-- TMPL_IF NAME="picture" -->
    // new YAHOO.widget.Button("delpicture");   // FIXME: formatting mismatch between YUI and normal button
	$('#delpicture').click(function(){
		 return confirm(_('Are you sure you want to delete this patron image? This cannot be undone.'));
	});
	$('#manage-patron-image').find("input[value*=Upload]").click(function(){
        if($("#uploadfile").val() == ""){
            alert(_("Please choose a file to upload"));
            return false;
        }
        return confirm(_('Are you sure you want to replace the current patron image? This cannot be undone.'));
	});<!-- /TMPL_IF -->
	$("#renew_all"      ).click(function(){ $(".checkboxed").checkCheckboxes(":input[name*=items]"   ); $(".checkboxed").unCheckCheckboxes(":input[name*=barcodes]"); });
	$("#return_all"     ).click(function(){ $(".checkboxed").checkCheckboxes(":input[name*=barcodes]"); $(".checkboxed").unCheckCheckboxes(":input[name*=items]"   ); });
	$("#CheckAllitems"  ).click(function(){ $(".checkboxed").checkCheckboxes(":input[name*=items]"   ); $(".checkboxed").unCheckCheckboxes(":input[name*=barcodes]"); return false; });
    $("#CheckNoitems"   ).click(function(){ $(".checkboxed").unCheckCheckboxes(":input[name*=items]"); return false; });
	$("#CheckAllreturns").click(function(){ $(".checkboxed").checkCheckboxes(":input[name*=barcodes]"); $(".checkboxed").unCheckCheckboxes(":input[name*=items]"); return false; });
    $("#CheckNoreturns" ).click(function(){ $(".checkboxed").unCheckCheckboxes(":input[name*=barcodes]"); return false; });

    <!-- TMPL_IF NAME="CAN_user_circulate_override_renewals" -->
    <!-- TMPL_IF NAME="AllowRenewalLimitOverride" -->
    $( '#override_limit' ).click( function () {
        if ( this.checked ) {
           $( '.renewals-allowed' ).show(); $( '.renewals-disabled' ).hide();
        } else {
           $( '.renewals-allowed' ).hide(); $( '.renewals-disabled' ).show();
        }
    } ).attr( 'checked', false );
    <!-- /TMPL_IF -->
    <!-- /TMPL_IF -->
	$("td").click(function(e){
		if(e.target.tagName.toLowerCase() == 'td'){
           $(this).find("input:checkbox").each( function() {
               $(this).attr('checked', !$(this).attr('checked'));
			   if($(this).attr('checked')){
                    $(this).parent().siblings().find("input:checkbox").each(function(){
                       if($(this).attr('checked')){ $(this).attr('checked',''); }
                   });
			   }
           });
		}
	});

  $('#SuspendAll').click(
    function() {
      $("INPUT[class='suspend_checkbox']").attr('checked', $('#SuspendAll').is(':checked'));
    }
  );

 });

function confirmCancelWaiting(that) {
   if (that.selectedIndex==0) { return; }
   var ans = confirm('This is currently on the hold shelf.\n'
   +'Are you sure you want to cancel this hold?');
   if (ans==true) {
      // do nothing
   }
   else {
      that.selectedIndex = 0;
   }
}
</script>

<div id="finesholdsissues" class="toptabs">
  <ul>
    <!-- TMPL_IF NAME="CAN_user_circulate_view_checkout" -->
    <li><a href="#checkedout">Checked Out</a></li>
    <!-- /TMPL_IF -->
    <!-- TMPL_IF NAME="CAN_user_updatecharges_view_charges" -->
    <li><a href="#finesandcharges">Fines &amp; Charges</a></li>
    <!-- /TMPL_IF -->
    <!-- TMPL_IF NAME="CAN_user_reserveforothers_view_holds" -->
    <li><a href="#onhold" id="onholdlink">On Hold (<TMPL_VAR NAME="countreserv">)</a></li>
    <!-- /TMPL_IF -->
    <li><a href="#revisionhistory">Revision History</a></li>
  </ul>
</div>

<!-- TMPL_IF NAME="CAN_user_updatecharges_view_charges" -->
<div id="finesandcharges">
  <!-- TMPL_IF NAME="totaldue_raw" -->
  <p>Total due: <!-- TMPL_VAR NAME="totaldue" --></p>
  <!-- TMPL_ELSE -->
  <p>No outstanding charges</p>
  <!-- /TMPL_IF -->
</div>
<!-- /TMPL_IF -->

<div id="revisionhistory">
  <h2>Revision History</h2>
  <!-- TMPL_IF NAME="revisionloop" -->
  <table id="revisionst">
    <thead><tr>
        <th>Staff</th>
        <th>Action</th>
        <th>Date/Time</th>
    </tr></thead>
    <tbody><!-- TMPL_LOOP NAME="revisionloop" -->
      <tr>
        <td><a href="/cgi-bin/koha/members/moremember.pl?borrowernumber=<!-- TMPL_VAR NAME="staffnumber" -->" title="display detail for this librarian.">
            <!-- TMPL_VAR NAME="staffnumber" --> </a></td>
        <td><!-- TMPL_VAR NAME="staffaction" --></td>
        <td><!-- TMPL_VAR NAME="timestamp" --></td>
      </tr>
      <!-- /TMPL_LOOP --></tbody>
  </table>
  <!-- TMPL_ELSE -->
  <p>Patron has no revisions.</p>
  <!-- /TMPL_IF -->
</div>

<!-- TMPL_IF NAME="CAN_user_circulate_view_checkout" -->
<div id="checkedout">
  <!-- TMPL_IF NAME="issueloop" -->
  <form action="/cgi-bin/koha/reserve/renewscript.pl" method="post" class="checkboxed">
    <input type="hidden" name="cardnumber"     value="<TMPL_VAR NAME="cardnumber">">
    <input type="hidden" name="borrowernumber" value="<!-- TMPL_VAR NAME="borrowernumber" -->" />
    <input type="hidden" name="branch" value="<!-- TMPL_VAR NAME="branch" -->" />
    <table id="issuest">
      <thead>
	<tr>
          <th scope="col">Due date</th>
          <th scope="col">Title</th>
          <th scope="col">Item Type</th>
          <th scope="col">Checked out on</th> 
	  <th scope="col">Library</th>
          <th scope="col">Call no</th>
          <th scope="col">Charge</th>
          <th scope="col">Price</th>
          <th scope="col">Renew <p class="column-tool"><a href="#" id="CheckAllitems">select all</a> | <a href="#" id="CheckNoitems">none</a></p></th>
          <!-- TMPL_IF NAME="dispreturn" -->
          <th scope="col">Check in <p class="column-tool"><a href="#" id="CheckAllreturns">select all</a> | <a href="#" id="CheckNoreturns">none</a></p></th>
          <!-- /TMPL_IF>
               </tr></thead>
      <tfoot>
	<tr>
          <td colspan="6" style="text-align: right; font-weight:bold;">Totals:</td>
	  <td><!-- TMPL_VAR NAME="totaldue" --></td>
          <td><!-- TMPL_VAR NAME="totalprice" --></td>
          <td>
            <p>
              Renewal due date: <input type="text" size="8" id="newduedate" name="newduedate" value="<!-- TMPL_VAR Name="newduedate" -->" />
              <img src="<!-- TMPL_VAR Name="themelang" -->/lib/calendar/cal.gif" id="newduedate_button" alt="Show Calendar" />
              <script type="text/javascript">
                //<![CDATA[
                        Calendar.setup({
                            inputField : "newduedate",
                            ifFormat : "<!-- TMPL_VAR NAME="DHTMLcalendar_dateformat" -->",
                            button : "newduedate_button"
                        });
                        //]]>
              </script>
            </p>
            <p>
              <!-- TMPL_IF NAME="CAN_user_circulate_exempt_fines" -->
              Forgive fines on return: <input type="checkbox" name="exemptfine" value="1" />
              <!-- TMPL_ELSE -->
              <input type="hidden" name="exemptfine" value="0" />
              <!-- /TMPL_IF -->
            </p>
          </td>
        </tr>
      </tfoot>
      <tbody>
        <!-- TMPL_LOOP name="issueloop" -->

        <!-- TMPL_IF name="overdue" -->
        <tr class="problem">
        <!-- TMPL_ELSE -->
        <tr>
          <!-- /TMPL_IF -->
	  <td<!-- TMPL_IF NAME="red" --> class="od"<!-- /TMPL_IF -->><!-- TMPL_VAR NAME="date_due" -->
            <!-- TMPL_IF NAME="itemlost" -->
            <span class="lost"><!-- TMPL_VAR NAME="itemlost" --></span>
            <!-- /TMPL_IF -->
            <!-- TMPL_IF NAME="damaged" -->
            <span class="dmg"><!-- TMPL_VAR NAME="itemdamaged" --></span>
            <!-- /TMPL_IF -->
          </td>
          <td><a href="/cgi-bin/koha/catalogue/detail.pl?biblionumber=<!-- TMPL_VAR NAME="biblionumber" -->"><strong><!-- TMPL_VAR NAME="title" escape="html" --></strong></a><!-- TMPL_IF NAME="author" -->, by <!-- TMPL_VAR name="author" --><!-- /TMPL_IF --> <!-- TMPL_IF name="publishercode" -->; <!-- TMPL_VAR name="publishercode" --> <!-- /TMPL_IF --> <!-- TMPL_IF name="publicationyear" -->, <!-- TMPL_VAR name="publicationyear" --><!-- /TMPL_IF --> 
            <!-- TMPL_IF NAME="itemnotes" -->
            - <!-- TMPL_VAR NAME="itemnotes" -->
            <!-- /TMPL_IF -->
            <a href="/cgi-bin/koha/catalogue/moredetail.pl?biblionumber=<!-- TMPL_VAR NAME="biblionumber" -->&amp;itemnumber=<!-- TMPL_VAR NAME="itemnumber" -->#item<!-- TMPL_VAR NAME="itemnumber" -->"><!-- TMPL_VAR NAME="barcode" --></a></td>
          <td><!-- TMPL_UNLESS NAME="noItemTypeImages" --> <!-- TMPL_IF NAME="itemtype_image" --><img src="<!-- TMPL_VAR NAME="itemtype_image" -->" alt="" /><!-- /TMPL_IF --><!-- /TMPL_UNLESS --><!-- TMPL_VAR NAME="itemtype_description" --></td>
          <td><!-- TMPL_VAR NAME="issuedate" --></td>
          <td><!-- TMPL_VAR NAME="branchcode" --></td>
          <td><!-- TMPL_VAR NAME="itemcallnumber" --></td>
          <td><!-- TMPL_VAR NAME="charge" --></td>
          <td><!-- TMPL_VAR NAME="replacementprice" --></td>
          <!-- TMPL_IF NAME="renew_failed" -->
          <td class="problem">Renewal Failed</td>
          <!-- TMPL_ELSE -->
          <td><span style="padding: 0 1em;"><!-- TMPL_VAR NAME="renewals" --> <!-- TMPL_IF NAME="renewals_opac" -->( <!-- TMPL_VAR NAME="renewals_opac" --> via OPAC ) <!-- /TMPL_IF --></span>
            <!-- TMPL_IF name="norenew" -->
            <!-- TMPL_IF NAME="can_confirm" --><span class="renewals-allowed" style="display: none">
              <input type="checkbox" name="all_items[]" value="<!-- TMPL_VAR NAME="itemnumber" -->" checked="checked" style="display: none;" />
              <!-- TMPL_IF NAME="od" -->
              <input type="checkbox" name="items[]" value="<!-- TMPL_VAR NAME="itemnumber" -->" checked="checked" />
              <!-- TMPL_ELSE -->
              <input type="checkbox" name="items[]" value="<!-- TMPL_VAR NAME="itemnumber" -->" />
              <!-- /TMPL_IF -->
            </span>
            <span class="renewals-disabled">
              <!-- /TMPL_IF -->
              <!-- TMPL_IF NAME="norenew_reason_on_reserve" -->
              <a href="/cgi-bin/koha/reserve/editholds.pl?biblionumber=<!-- TMPL_VAR NAME="biblionumber" -->">On Hold</a>
              <!-- /TMPL_IF -->
	          <!-- TMPL_IF NAME="norenew_reason_too_many" -->
	          Not Renewable
	          <!-- /TMPL_IF -->
              <!-- TMPL_IF NAME="can_confirm" -->
            </span>
            <!-- /TMPL_IF -->
            <!-- TMPL_ELSE -->
            <input type="checkbox" name="all_items[]" value="<!-- TMPL_VAR NAME="itemnumber" -->" checked="checked" style="display: none;" />
            <!-- TMPL_IF NAME="red" -->
            <input type="checkbox" name="items[]" value="<!-- TMPL_VAR NAME="itemnumber" -->" checked="checked" onclick="uncheck_sibling(this);" />
            <!-- TMPL_ELSE -->
            <input type="checkbox" name="items[]" value="<!-- TMPL_VAR NAME="itemnumber" -->" onclick="uncheck_sibling(this);" />
            <!-- /TMPL_IF -->
            <!-- /TMPL_IF -->
          </td>
          <!-- /TMPL_IF -->
          <!-- TMPL_IF NAME="dispreturn" -->
          <!-- TMPL_IF NAME="return_failed" -->
          <td class="problem">Checkin Failed</td>
          <!-- TMPL_ELSE -->
          <td><input type="checkbox" name="barcodes[]"  value="<!-- TMPL_VAR NAME="barcode" -->" onclick="uncheck_sibling(this);" />
            <input type="checkbox" name="all_barcodes[]" value="<!-- TMPL_VAR NAME="barcode" -->" checked="checked" style="display: none;" />
          </td>
          <!-- /TMPL_IF -->
          <!-- /TMPL_IF -->
        </tr>
        <!-- /tmpl_loop --></tbody>
    </table>
    <fieldset class="action">
      <!-- TMPL_IF NAME="CAN_user_circulate_override_renewals" -->
      <!-- TMPL_IF NAME="AllowRenewalLimitOverride" -->
      <label for="override_limit">Override Renewal Limit:</label>
      <input type="checkbox" name="override_limit" id="override_limit" value="1" />
      <!-- /TMPL_IF -->
      <!-- /TMPL_IF -->
      <!-- TMPL_IF NAME="dispreturn" -->
      <input type="submit" name="renew_checked" value="Renew or Return checked items" />
      <!--TMPL_ELSE-->
      <input type="submit" name="renew_checked" value="Renew checked items" />
      <!-- /TMPL_IF -->
      <input type="submit" id="renew_all" name="renew_all" value="Renew all" />
      <!-- TMPL_IF NAME="dispreturn" -->
      <input type="submit" id="return_all" name="return_all" value="Return all" />
      <!-- /TMPL_IF -->
    </fieldset>
  </form>
  <!-- TMPL_ELSE -->
  <p>Patron has nothing checked out.</p>
  <!-- /TMPL_IF -->
</div>
<!-- /TMPL_IF -->
<!-- /TMPL_IF -->

<!-- TMPL_IF NAME="CAN_user_reserveforothers_view_holds" -->
<div id="onhold">
  <!-- TMPL_IF NAME="reservloop" -->
  <form name="modifyReservesForm" action="/cgi-bin/koha/reserve/modrequest.pl" method="post" >
    <input type="hidden" name="from" value="borrower" />
    <table id="holdst">
      <thead><tr>
          <th>Branch</th>
	  <th>Placed</th>
	  <th>Expires</th>
	  <th>Title</th>
          <th>Note</th>
          <th>Item Type</th>
	  <th>Call Number</th>
	  <th>Barcode</th>
	  <th>Rank</th>
	  <th>Cancel?</th>
          <th>Suspend?<br/>(all: <input type="checkbox" id="SuspendAll"/>)</th>
      </tr></thead>
      <tbody><!-- TMPL_LOOP NAME="reservloop" -->
	<tr class="<!-- TMPL_VAR NAME="color" -->">
          <td><TMPL_VAR NAME="pickupbranch"></td>
          <td><!-- TMPL_VAR NAME="reservedate" --></td>
          <td align=center><!-- TMPL_VAR NAME="holdexpdate" --></td>
          <td><a href="/cgi-bin/koha/reserve/editholds.pl?biblionumber=<!-- TMPL_VAR NAME="biblionumber" -->" title="<!-- TMPL_IF NAME="reserves_245b" --><!-- TMPL_VAR NAME="reserves_245b" --><!-- /TMPL_IF --><!-- TMPL_IF NAME="reserves_245h" --> <!-- TMPL_VAR NAME="reserves_245h" --><!-- /TMPL_IF --><!-- TMPL_IF NAME="reserves_245n" --> <!-- TMPL_VAR NAME="reserves_245n" --><!-- /TMPL_IF --><!-- TMPL_IF NAME="reserves_245p" --> <!-- TMPL_VAR NAME="reserves_245p" --><!-- /TMPL_IF --><!-- TMPL_IF NAME="reserves_260c" --> <!-- TMPL_VAR NAME="reserves_260c" --><!-- /TMPL_IF --><!-- TMPL_IF NAME="callnumber" --> <!-- TMPL_VAR NAME="callnumber" --><!-- /TMPL_IF --><!-- TMPL_IF NAME="enumchron" --> <!-- TMPL_VAR NAME="enumchron" --><!-- /TMPL_IF --><!-- TMPL_IF NAME="copynumber" --> Copy: <!-- TMPL_VAR NAME="copynumber" --><!-- /TMPL_IF -->"><!-- TMPL_VAR NAME="title" escape="html" --></a><!-- TMPL_IF NAME="author" -->, by <!-- TMPL_VAR NAME="author" --><!-- /TMPL_IF --></td>
          <td><TMPL_VAR NAME="reservenotes"></td>
          <td><!-- TMPL_VAR NAME="itemtype" --></td>
          <td><!-- TMPL_VAR NAME="itemcallnumber" --></td>
          <td>
	    <!-- TMPL_IF EXPR="!waiting && !transfered && barcodereserv" -->
            Only item
            <!-- /TMPL_IF -->
            <!-- TMPL_IF EXPR="waiting || tranferred" -->
            Selected item
            <!-- /TMPL_IF -->
            <!-- TMPL_IF name="barcodereserv" -->
            <a href="/cgi-bin/koha/catalogue/moredetail.pl?biblionumber=<!-- TMPL_VAR NAME="biblionumber" -->&itemnumber=<TMPL_VAR NAME="itemnumber">#item<TMPL_VAR NAME="itemnumber">"><!-- TMPL_VAR NAME="barcodereserv" --></a>
            <!-- /TMPL_IF -->
          </td>
          <td><!-- TMPL_IF name="waiting" -->
            <em>Item is <strong>waiting</strong></em>
            <!-- TMPL_ELSIF name="transfered" -->
            <em>Item <strong>in transit</strong> from
              <!-- TMPL_VAR NAME="frombranch" --> since <!-- TMPL_VAR NAME="datesent" --> </em>
            <!-- TMPL_ELSIF name="nottransfered" -->
            <em>Item hasn't been transfered yet from <!-- TMPL_VAR NAME="nottransferedby" --></em>
            <!-- /TMPL_IF -->
	    <!-- TMPL_IF NAME="waitingposition" --><strong><!-- TMPL_VAR NAME="waitingposition" --></strong><!-- /TMPL_IF --></td>
          <!-- TMPL_IF NAME="waiting" -->
          <!-- TMPL_IF NAME="CAN_user_reserveforothers_delete_waiting_holds" -->
          <td><select name="rank_request" onchange="confirmCancelWaiting(this)">
              <option value="n">No</option>
              <option value="del">Yes</option>
            </select>
            <!-- TMPL_ELSE -->
          <td>No
            <input type="hidden" name="rank_request" value="n" />
            <!-- /TMPL_IF -->
            <!-- TMPL_ELSE -->
	  <td><select name="rank_request">
	      <option value="n">No</option>
	      <option value="del">Yes</option>
	    </select>
            <!-- /TMPL_IF -->
	    <input type="hidden" name="reservenumber" value="<!-- TMPL_VAR name="reservenumber" -->" />
	    <input type="hidden" name="biblionumber" value="<!-- TMPL_VAR name="biblionumber" -->" />
	    <input type="hidden" name="borrowernumber" value="<!-- TMPL_VAR name="borrowernumber" -->" /></td>
	  <td>
	    <!-- TMPL_IF EXPR="waiting || transfered" -->
	    Cannot Suspend Waiting or In-transit Items
	    <!-- TMPL_ELSE -->
	    <input type="checkbox" class="suspend_checkbox" name="suspend_<!-- TMPL_VAR NAME="reservenumber" -->" <TMPL_IF NAME="suspended">checked</TMPL_IF> value="1" />
	    <label>Resume on (optional):</label>
	    <input type="text" size="10" maxlength="10" id="resumedate_<!-- TMPL_VAR NAME="reservenumber" -->" name="resumedate_<!-- TMPL_VAR NAME="reservenumber" -->" value="<TMPL_VAR NAME="waitingdate">" />
            <script type="text/javascript">
              Calendar.setup({
              inputField: "resumedate_<TMPL_VAR NAME="reservenumber">",
                ifFormat: "<!-- TMPL_VAR NAME="DHTMLcalendar_dateformat" -->",
                button: "resumedate_<TMPL_VAR NAME="reservenumber">",
                  align: "T1"
                  });
            </script>
	    <!-- /TMPL_IF -->
	  </td>
	</tr>
	<!-- /TMPL_LOOP --></tbody>
    </table>
    <input type=hidden name="opentab_holds" value="1">
    <fieldset class="action"><input type="submit" class="cancel" name="submit" value="Update Holds" /></fieldset>
  </form>
  <!-- TMPL_ELSE -->
  <p>Patron has nothing on hold.</p>
  <!-- /TMPL_IF -->
</div>
<!-- /TMPL_IF -->
