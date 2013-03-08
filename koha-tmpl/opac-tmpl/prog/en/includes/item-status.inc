<!-- TMPL_IF name="notforloan_per_itemtype" -->
    <!-- TMPL_IF NAME="opacnotforloandesc" -->
      <!-- TMPL_VAR NAME="opacnotforloandesc" -->
    <!-- TMPL_ELSIF NAME="notforloandesc" -->
      <!-- TMPL_VAR NAME="notforloandesc" -->
    <!-- TMPL_ELSE -->
      Item type not for loan
    <!-- /TMPL_IF -->
<!-- TMPL_ELSE -->
    <!-- TMPL_IF name="datedue" -->
        <!-- TMPL_IF name="OPACShowCheckoutName" -->
            Checked out to <!-- TMPL_VAR NAME="cardnumber" --> <!-- TMPL_VAR NAME="firstname" --> <!-- TMPL_VAR NAME="surname" -->
        <!-- TMPL_ELSE -->
            Checked out
        <!-- /TMPL_IF -->
    <!-- TMPL_ELSE -->
        <!-- TMPL_IF name="itemnotforloan" -->
            <!-- TMPL_IF NAME="opacnotforloandesc" -->
              <!-- TMPL_VAR NAME="opacnotforloandesc" -->
            <!-- TMPL_ELSIF NAME="notforloandesc" -->
              <!-- TMPL_VAR NAME="notforloandesc" -->
            <!-- TMPL_ELSE -->
              Item type not for loan
            <!-- /TMPL_IF -->
        <!-- TMPL_ELSE -->
            <!-- TMPL_IF name="itemlost"-->
                <!-- TMPL_IF name="lostimageurl"-->
                    <img src="<!-- TMPL_VAR NAME="lostimageurl" -->" alt="<!-- TMPL_VAR NAME="lostimagelabel" -->" title="<!-- TMPL_VAR NAME="lostimagelabel" -->">
                <!-- TMPL_ELSE -->
                    <!-- TMPL_IF NAME="opacitemlostdesc" -->
                      <!-- TMPL_VAR NAME="opacitemlostdesc" -->
                    <!-- TMPL_ELSIF NAME="itemlostdesc" -->
                      <!-- TMPL_VAR NAME="itemlostdesc" -->
                    <!-- TMPL_ELSE -->
                      Item lost
                    <!-- /TMPL_IF -->
                <!-- /TMPL_IF -->
            <!-- TMPL_ELSE -->
                <!-- TMPL_IF NAME="wthdrawn" -->
                    <!-- TMPL_IF NAME="opacwthdrawndesc" -->
                      <!-- TMPL_VAR NAME="opacwthdrawndesc" -->
                    <!-- TMPL_ELSIF NAME="wthdrawndesc" -->
                      <!-- TMPL_VAR NAME="wthdrawndesc" -->
                    <!-- TMPL_ELSE -->
                      Item withdrawn
                <!-- /TMPL_IF -->
                <!-- TMPL_ELSIF NAME="damaged" -->
                    <!-- TMPL_IF NAME="opacdamageddesc" -->
                      <!-- TMPL_VAR NAME="opacdamageddesc" -->
                    <!-- TMPL_ELSIF NAME="damageddesc" -->
                      <!-- TMPL_VAR NAME="damageddesc" -->
                    <!-- TMPL_ELSE -->
                       Item Damaged
                    <!-- /TMPL_IF -->
                <!-- TMPL_ELSIF NAME="otherstatus_description" -->
                    <!-- TMPL_VAR NAME="otherstatus_description" -->
                <!-- TMPL_ELSIF Name="transfertwhen" -->
                    In transit from <!-- TMPL_VAR NAME="transfertfrom" -->
                    to <!-- TMPL_VAR NAME="transfertto" --> since <!-- TMPL_VAR NAME="transfertwhen" -->
                <!-- TMPL_ELSE -->
                    <!-- TMPL_IF NAME="waiting" --><span class="HoldsLabel">On hold</span><!-- TMPL_ELSE -->Available<!-- /TMPL_IF -->
                <!-- /TMPL_IF -->
            <!-- /TMPL_IF -->
        <!-- /TMPL_IF -->
    <!-- /TMPL_IF -->
<!-- /TMPL_IF -->
