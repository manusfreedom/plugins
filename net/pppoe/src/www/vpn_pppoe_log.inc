<?php

/*
    Copyright (C) 2014-2016 Deciso B.V.
    Copyright (C) 2003-2006 Manuel Kasper <mk@neon1.net>
    All rights reserved.

    Redistribution and use in source and binary forms, with or without
    modification, are permitted provided that the following conditions are met:

    1. Redistributions of source code must retain the above copyright notice,
       this list of conditions and the following disclaimer.

    2. Redistributions in binary form must reproduce the above copyright
       notice, this list of conditions and the following disclaimer in the
       documentation and/or other materials provided with the distribution.

    THIS SOFTWARE IS PROVIDED ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES,
    INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
    AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
    AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY,
    OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
    SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
    INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
    CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
    ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
    POSSIBILITY OF SUCH DAMAGE.
*/

require_once("guiconfig.inc");
require_once("system.inc");
require_once('services.inc');
require_once('plugins.inc');
require_once("interfaces.inc");

if (empty($config['syslog']['nentries'])) {
    $nentries = 50;
} else {
    $nentries = $config['syslog']['nentries'];
}

if ($_POST['clear']) {
    system_clear_clog($logfile);
}

function dump_clog_vpn($file, $tail, $type)
{
    global $config;

    $sort = isset($config['syslog']['reverse']) ? '-r' : '';
    $logarr = array();

    exec("/usr/local/sbin/clog " . escapeshellarg($file) . " | tail {$sort} -n " . escapeshellarg($tail), $logarr);

    foreach ($logarr as $logent) {
        $logent = preg_split('/\s+/', $logent, 6);
        $llent = explode(',', $logent[5]);

        if ($llent[1] !== $type) {
            continue;
        }

        echo "<tr>\n";
        echo "<td class=\"listlr nowrap\">" . htmlspecialchars(join(" ", array_slice($logent, 0, 3))) . "</td>\n";

        if ($llent[0] == "login") {
            echo "<td class=\"listr\"><span class=\"glyphicon glyphicon-arrow-right\" aria-hidden=\"true\" alt=\"in\"></span></td>\n";
        } else {
            echo "<td class=\"listr\"><span class=\"glyphicon glyphicon-arrow-left\" aria-hidden=\"true\" alt=\"out\"></span></td>\n";
        }

        echo "<td class=\"listr\">" . htmlspecialchars($llent[3]) . "</td>\n";
        echo "<td class=\"listr\">" . htmlspecialchars($llent[2]) . "&nbsp;</td>\n";
        echo "</tr>\n";
    }
}

include("head.inc");
?>

<body>
<?php include("fbegin.inc"); ?>

<section class="page-content-main">
  <div class="container-fluid">
    <div class="row">
      <section class="col-xs-12">
        <div class="tab-content content-box col-xs-12">
          <div class="table-responsive">
            <table class="table table-striped table-sort">
              <tr>
                <td class="listhdrr"><?=gettext("Time");?></td>
                <td class="listhdrr"><?=gettext("Action");?></td>
                <td class="listhdrr"><?=gettext("User");?></td>
                <td class="listhdrr"><?=gettext("IP address");?></td>
              </tr>
              <tr>
                <td colspan="4">
                  <ul class="nav nav-pills" role="tablist">
                    <?php foreach ($logpills as $pill): ?>
                      <li role="presentation" <?php if (str_replace('amp;','', $pill[2]) == $_SERVER['REQUEST_URI']):?>class="active"<?php endif; ?>><a href="<?=$pill[2];?>"><?=$pill[0];?></a></li>
                      <?php endforeach; ?>
                  </ul>
                </td>
              </tr>
              <?php dump_clog_vpn($logfile, $nentries, $logtype); ?>
              <tr>
                <td colspan="4">
                  <form method="post">
                    <input type="hidden" name="mode" id="mode" value="<?= html_safe($mode) ?>"/>
                    <input name="clear" type="submit" class="btn btn-primary" value="<?= html_safe(gettext('Clear log')) ?>"/>
                  </form>
                </td>
              </tr>
            </table>
          </div>
        </div>
      </section>
    </div>
  </div>
</section>
<?php include("foot.inc"); ?>
