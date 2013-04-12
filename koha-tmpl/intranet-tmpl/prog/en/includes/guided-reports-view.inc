<!-- guided-reports-view.inc -->

<script type="text/javascript" src="<!-- TMPL_VAR name="themelang" -->/lib/jquery/plugins/jquery.tablesorter.min.js"></script>

<h5>Build and Run Reports</h5>
<ul>
<li><a href="/cgi-bin/koha/reports/guided_reports.pl?phase=Build%20new">Build New</a></li>
<li><a href="/cgi-bin/koha/reports/guided_reports.pl?phase=Use%20saved">Use Saved</a></li>
<li><a href="/cgi-bin/koha/reports/guided_reports.pl?phase=Create%20report%20from%20SQL">Create from SQL</a></li>
</ul>

<h5>Reports Dictionary</h5>
<ul>
<li><a href="/cgi-bin/koha/reports/dictionary.pl?phase=View%20Dictionary">View Dictionary</a></li>
</ul>

<h5>Resources</h5>
<ul>
<li><a target="_blank" href="http://cdn.kohalibrary.com/c/Docs/LibLimeSampleReports.htm">LibLime Reports Library</a></li>
<li><a target="_blank" href="http://dev.mysql.com/doc/">MySQL Documentation</a></li>
</ul>

<form id="guided_report_tagger" method="post" action="/cgi-bin/koha/reports/guided_reports_tags.pl">
  <table id="tags" width="100%">
    <thead>
      <tr>
        <th colspan="3">Tags</th>
      </tr>
    </thead>
    <tfoot>
      <tr>
        <td><img class="loader" style="display: none" src="/intranet-tmpl/prog/img/loading-small.gif" alt="loading" /></td>
        <td colspan="2"><input type="text" name="tag" size="7"/> <input type="submit" name="add" value="Add" /></td>
      </tr>
    </tfoot>
    <tbody>
    <!-- TMPL_LOOP NAME="tag_frequency" -->
      <tr>
        <td class="closer"><a class="closer" href="/cgi-bin/koha/reports/guided_reports_tags.pl?action=remove&amp;tag=<!-- TMPL_VAR NAME="tag" ESCAPE=URL -->&amp;redirect_to=<!-- TMPL_VAR NAME="redirect_to" -->">x</a></td>
        <td><a class="tag" href="/cgi-bin/koha/reports/guided_reports.pl?phase=Use%20saved&amp;tag=<!-- TMPL_VAR NAME="tag" ESCAPE=URL -->"><!-- TMPL_VAR NAME="tag" --></a></td>
        <td class="frequency"><!-- TMPL_VAR NAME="frequency" --></td>
      </tr>
    <!-- /TMPL_LOOP -->
    </tbody>
  </table>
  <input type="hidden" name="action"      value="add" />
  <input type="hidden" name="redirect_to" value="<!-- TMPL_VAR NAME="redirect_to" -->" />
</form>

<div class="factory" style="display: none">
  <table>
    <tbody>
      <tr>
        <td class="closer"><a class="closer" href="/cgi-bin/koha/reports/guided_reports_tags.pl?action=remove&amp;tag=____tag____&amp;redirect_to=<!-- TMPL_VAR NAME="redirect_to" -->">x</a></td>
        <td><a class="tag" href="/cgi-bin/koha/reports/guided_reports.pl?phase=Use%20saved&amp;tag=____tag____"></a></td>
        <td class="frequency">0</td>
      </tr>
    </tbody>
  </table>
  <form action="/">
    <select>
      <option value=""></option>
    </select>
  </form>
</div>

<script type="text/javascript">
$(function(){

    // DOM manipulation functions for tag interface
    var tagInterface = {
        add: function(tag) {
            var tr = $('div.factory tr').clone();
            var closerURL = $('a.closer', tr).attr('href');
            var tagURL = $('a.tag', tr).attr('href');
            var encodedTag = encodeURIComponent(tag);
            $('a.tag', tr).html(tag);
            $('a.tag', tr).attr('href', tagURL.replace(/____tag____/, encodedTag));
            $('a.closer', tr).attr('href', closerURL.replace(/____tag____/, encodedTag));
            $('#guided_report_tagger tbody').append(tr);
            var select = $('#actions');
            if (select.length) {
                var option = $('div.factory option').clone();
                option.attr('value', 'tag:' + tag);
                option.html('&nbsp;&nbsp;' + tag);
                $('#end_of_tags').before(option);
            }
        },
        remove: function(tag) {
            $('#guided_report_tagger a.tag').each(function(i, el){
                var link = $(el);
                if (link.html() == tag) {
                    link.parent().parent().remove();
                    return true;
                }
            });
            var select = $('#actions');
            if (select.length) {
                $('#actions option').each(function(i, el){
                    var value = $(el).attr('value').replace(/^tag:/, '');
                    if (value == tag) {
                        $(el).remove();
                        return true;
                    }
                });
            }
            var table = $('#reports');
            if (table.length) {
                $('tbody span.tag').each(function(i, el){
                    var text = $(el).text();
                    if (text == tag) {
                        $(el).remove();
                        // keep going ; don't return right away
                    }
                });
            }
        }
    };

    // tr.selected when checkbox is clicked
    $('#reports tbody input[type=checkbox]').click(function(ev){
        $(this).parents('tr').toggleClass('selected');
    });

    // tr.selected when checkbox is clicked (even if they hit back or reload the page)
    $('#reports tbody input[type=checkbox]:checked').each(function(i, el){
        $(this).parents('tr').addClass('selected');
    });

    // make list of reports sortable
    $('#reports').tablesorter({
        headers: {
            0: { sorter: false },
            5: { sorter: false }
        },
        textExtraction: function(cell){
            if ($('a.report_title', cell) > 0) {
                return $('a.report_title', cell).text();
            }
            return $(cell).text();
        }
    });

    // Create tags on submit
    $('#guided_report_tagger').submit(function(ev){
        var self        = this;
        var request = { action: 'add', tag: $('input[type=text]', this).val() };
        var url         = $(this).attr('action');
        $('#guided_report_tagger img.loader').show();
        $.post(
            url,
            request,
            function(response, textStatus) {
                if (response.success) {
                    tagInterface.add(request.tag);
                    $('input[type=text]', self).val('');
                }
                $('#guided_report_tagger img.loader').hide();
            },
            "json"
        );
        return false;
    });

    // Remove tags on click
    $('#guided_report_tagger a.closer').live('click', function(ev){
        var self        = this;
        var form        = $(this).parents('form');
        var request = { };
        if (ev.button == 0) {
            request.action = 'remove';
            request.tag    = $($(this).parents('tr').find('td a.tag').get(0)).text();
            var url = form.attr('action');
            $('#guided_report_tagger img.loader').show();
            $.post(
                url,
                request,
                function(response, textStatus){
                    if (response.success) {
                        tagInterface.remove(request.tag);
                    }
                    $('#guided_report_tagger img.loader').hide();
                },
                "json"
            );
        }
        return false;
    });

});
</script>
