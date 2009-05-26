<!-- TMPL_LOOP NAME="item" -->
    <li style="<!-- TMPL_VAR NAME='visibility' -->"><div class="subfield_line" id="subfield<!-- TMPL_VAR NAME='tag' --><!-- TMPL_VAR NAME='subfield' --><!-- TMPL_VAR name="random" -->">

        <label><!-- TMPL_VAR NAME="subfield" --> - <!-- TMPL_IF name="mandatory" --><b><!-- /TMPL_IF --><!-- TMPL_VAR NAME="marc_lib" --><!-- TMPL_IF name="mandatory" --> *</b><!-- /TMPL_IF --></label>
        <input type="hidden" name="indicator_<!-- TMPL_VAR NAME="item_index" -->" value="  " />
        <!-- TMPL_VAR NAME="marc_value" -->
        <input type="hidden" name="tag_<!-- TMPL_VAR NAME="item_index" -->"       value="<!-- TMPL_VAR NAME="tag" -->" />
        <input type="hidden" name="subfield_<!-- TMPL_VAR NAME="item_index" -->"  value="<!-- TMPL_VAR NAME="subfield" -->" />
        <input type="hidden" name="mandatory_<!-- TMPL_VAR NAME="item_index" -->" value="<!-- TMPL_VAR NAME="mandatory" -->" />
        <!-- TMPL_IF NAME="repeatable" -->
        <span class="buttonPlus" onclick="CloneSubfield('subfield<!-- TMPL_VAR NAME='tag' --><!-- TMPL_VAR NAME='subfield' --><!-- TMPL_VAR name="random" -->')">+</span>
        <!-- /TMPL_IF -->

    </div></li>
<!-- /TMPL_LOOP -->
