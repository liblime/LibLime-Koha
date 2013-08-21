    <!-- TMPL_IF name="datedue" -->
        <span class="datedue">Checked out
        <!-- TMPL_UNLESS  NAME="NOTSAMEBRANCH" -->
            to <a href="/cgi-bin/koha/members/moremember.pl?borrowernumber=<!-- TMPL_VAR NAME="borrowernumber" -->">
            <!-- TMPL_IF NAME='hidepatronname' -->
                <!-- TMPL_VAR NAME="cardnumber" -->
            <!-- TMPL_ELSE -->
                 <!-- TMPL_VAR NAME="firstname" --> <!-- TMPL_VAR NAME="surname" -->
            <!-- /TMPL_IF --></a>
        <!-- /TMPL_UNLESS -->
        : due <!-- TMPL_VAR NAME="datedue" --></span>
    <!-- TMPL_ELSIF Name="transfersince" -->
               In transit from <!-- TMPL_VAR NAME="transferfrom" -->,
               to <!-- TMPL_VAR NAME="transferto" -->
    <!-- /TMPL_IF -->

    <!-- TMPL_IF NAME="itemlost" -->
        <span class="lost"><!-- TMPL_VAR EXPR="default(itemlostdesc,'Unavailable (lost or missing)')" --></span>
    <!-- /TMPL_IF -->

    <!-- TMPL_IF NAME="wthdrawn" -->
        <span class="wdn"><!-- TMPL_VAR EXPR="default(wthdrawndesc,'Withdrawn')" --></span>
    <!-- /TMPL_IF -->

    <!-- TMPL_IF NAME="damaged" -->
        <span class="dmg"><!-- TMPL_VAR EXPR="default(damageddesc,'Damaged')" --></span>
    <!-- /TMPL_IF -->

    <!-- TMPL_IF NAME="otherstatus" -->
       <span class="lost"><!-- TMPL_VAR NAME="otherstatus_desc" --></span>
    <!-- /TMPL_IF -->

    <!-- TMPL_IF NAME="suppress" -->
            <span class="suppress"><!-- TMPL_VAR EXPR="default(suppressdesc,'Suppressed')" --></span>
    <!-- /TMPL_IF -->

    <!-- TMPL_IF Name="notforloan" -->
        <!-- TMPL_VAR NAME="notforloandesc" -->
    <!-- /TMPL_IF -->

    <!-- TMPL_IF NAME="reservedate"-->
        <!-- TMPL_IF NAME="waitingdate" -->
            Waiting
        <!-- TMPL_ELSE -->
            On hold
        <!-- /TMPL_IF -->
        <!-- TMPL_IF NAME="canreservefromotherbranches" -->for <a href="/cgi-bin/koha/members/moremember.pl?borrowernumber=<!-- TMPL_VAR NAME="ReservedForBorrowernumber" -->">
            <!-- TMPL_IF NAME="hidepatronname" -->
              <!-- TMPL_VAR NAME="cardnumber" -->
            <!-- TMPL_ELSE -->
              <!-- TMPL_VAR NAME="ReservedForFirstname" --> <!-- TMPL_VAR NAME="ReservedForSurname" -->
            <!-- /TMPL_IF -->
            </a>
        <!-- /TMPL_IF -->
        <!-- TMPL_IF ExpectedAtLibrary -->
            ,<!-- TMPL_UNLESS waitingdate --> expected <!-- /TMPL_UNLESS -->
            at <!-- TMPL_VAR NAME="ExpectedAtLibrary" -->
        <!-- /TMPL_IF -->
        since <!-- TMPL_VAR EXPR="default(date(waitingdate),date(reservedate))" -->
    <!-- /TMPL_IF -->

    <!-- TMPL_IF available -->Available<!-- /TMPL_IF -->

