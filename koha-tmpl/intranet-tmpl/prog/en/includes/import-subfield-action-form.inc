<li>
  <select name="action_type">
    <!-- TMPL_IF NAME="action_type_delete" --><option value="delete" selected="selected"><!-- TMPL_ELSE --><option value="delete"><!-- /TMPL_IF -->Remove:</option>
    <!-- TMPL_IF NAME="action_type_add_always" --><option value="add_always" selected="selected"><!-- TMPL_ELSE --><option value="add_always"><!-- /TMPL_IF -->Add:</option>
    <!-- TMPL_IF NAME="action_type_add" --><option value="add" selected="selected"><!-- TMPL_ELSE --><option value="add"><!-- /TMPL_IF -->Add, if not present:</option>
  </select>
  tag <input type="text" name="action_tag" value="<!-- TMPL_VAR NAME="action_tag" -->" size="3" maxlength="3" />
  subfield <input type="text" name="action_subfield" value="<!-- TMPL_VAR NAME="action_subfield" -->" size="1" maxlength="1" />
  <span class="action-contents-text" style="display: none"> with contents <input type="text" name="action_contents" value="" size="20" /></span>
  <input type="button" class="remove-action" value="-" />
  <input type="button" class="new-action" value="+" />
</li>
