<form name="f" method="get" action="authorities-home.pl">
            <input type="hidden" name="op" value="do_search" />
            <input type="hidden" name="type" value="intranet" />
            <input type="hidden" name="index" value="<!-- TMPL_VAR NAME="index" -->" />

                <fieldset class="rows"><ol><li>
                    <span class="label">Authority type</span>
                    <!-- TMPL_VAR NAME="authtypecode" -->
                    <input type="hidden" name="authtypecode" value="<!-- TMPL_VAR NAME="authtypecode" -->" />
                </li>

                <li>
                    <label for="mainentry">Search </label>
                <select name="idx">
                    <option value="auth-heading">Main heading</option>
                    <option value="auth-full">Full record</option>
                </select>
                <!--    <select name="operator" id="mainentry">
                        <option value="contains">contains</option>
                        <option value="start">starts with</option>
                        <option value="is">is exactly</option>
                    </select> -->
                    <input type="text" name="q" id="search_terms" value="<!-- TMPL_VAR ESCAPE="HTML" name="q" -->" />
                </li>
		<li>
		<label for="orderby">Sort by </label>
		<select name="orderby" id="orderby">
            <option value="auth-heading-sort asc" selected="selected">Heading A-Z</option>
            <option value="auth-heading-sort desc">Heading Z-A</option>
        </select>
		</li></ol></fieldset>
            <fieldset class="action"> <input type="submit" value="Start search" class="submit" /> <a class="cancel close" href="#">Cancel</a></fieldset>
</form>
