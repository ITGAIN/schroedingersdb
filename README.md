<!DOCTYPE html>
<html>

<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>SchroedingerDB</title>
  <link rel="stylesheet" href="https://stackedit.io/style.css" />
</head>

<body class="stackedit">
  <div class="stackedit__html"><h1 id="about-schroedingersdb">About SchroedingersDB</h1>
<p>A collection of scripts wrapped in a PL/SQL file to gather information about database usage to help you answer the questions</p>
<ol>
<li>is the database in use?</li>
<li>when has someone changed data within a non-oracle maintained schema?</li>
<li>when has someone logged in last time ?</li>
<li>Does jobs and triggers exist that might change data</li>
</ol>
<blockquote>
<p>“Sometimes you need to see inside the database to tell if it is dead or alive”</p>
</blockquote>
<h1 id="getting-started">Getting Started</h1>
<blockquote>
<p><strong>Disclaimer:  This script is provided “as is”, so no warranties or guarantees are made about its correctness, reliability and safety. Use it at your own risk!</strong></p>
</blockquote>
<h2 id="prerequisites">Prerequisites</h2>
<ol>
<li>
<p>procedure hasDiagPack checks if use of Diagnostic Pack is enabled.<br>
You may disable use of Diagnostic Pack permanently if you do not have a proper licence by setting variable disableDiagPack to 1</p>
</li>
<li>
<p>Script supports Oracle Database Version 12 or above</p>
</li>
<li>
<p>You need a user account with access to dictionary views.<br>
You need read permission on dba views like v$instance and v$database.</p>
</li>
<li>
<p>schema names are case sensitive</p>
</li>
</ol>
<h2 id="installation">Installation</h2>
<p>Download and unzip files to a new directory.</p>
<h1 id="usage">Usage</h1>
<p>Call script via sqlplus.</p>
<pre><code> sqlplus -S / as sysdba @schroedingerDB  &lt;Output Mode&gt; [&lt;Username&gt; [&lt;SCN check days back&gt;]]
 sqlplus -S &lt;user&gt;/&lt;pass&gt;@DB @schroedingerDB &lt;Output Mode&gt; [&lt;Username&gt; [&lt;SCN check days back&gt;]]
</code></pre>
<p>SCN conversation to time is either calculated by oracle internal conversation or by approximating via archive logs.</p>
<p>Examples:</p>
<p>Check all schemas for table modifications (2) and RowSCN first change (4)<br>
List DB Information (1) and show user information (64)</p>
<pre><code>sqlplus -S &lt;user&gt;/&lt;pass&gt;@DB @schroedingerDB 71   
</code></pre>
<p>Same checks, but only check schemas startin with NO</p>
<pre><code>sqlplus -S &lt;user&gt;/&lt;pass&gt;@DB @schroedingerDB 71 NO% 
</code></pre>
<h2 id="export-a-file">Export a file</h2>
<p>use pipe to export to file</p>
<pre><code>sqlplus -S &lt;user&gt;/&lt;pass&gt;@DB @schroedingerDB 71 | tee output.txt
</code></pre>
<h2 id="report-modes">Report Modes</h2>
<p>You can activate multiple modes by adding mode numbers, except for CheckMode.<br>
Only objects from non-oracle users are listed.<br>
Only one OraSCN mode will used.</p>

<table>
<thead>
<tr>
<th>Nr</th>
<th>Mode</th>
<th>Description</th>
</tr>
</thead>
<tbody>
<tr>
<td>0</td>
<td>Help</td>
<td>show help page</td>
</tr>
<tr>
<td>1</td>
<td>DB Info</td>
<td>Lists general information about the database</td>
</tr>
<tr>
<td>2</td>
<td>TabMod</td>
<td>Lists used tables based on dba_tab_modifications</td>
</tr>
<tr>
<td>4<br>8<br>16<br>32</td>
<td>ORASCN</td>
<td>Four different versions of SCN reports. Only one orascn reports is being executed: <p> 1. reports one table that has changed   <br> 2. reports one table that has changed for every schema  <br> 3. scans every table for changes, shows summery of first/last changes (long runtime)<br>4. scan last change on every table (long runtime )</p></td>
</tr>
<tr>
<td>64</td>
<td>Active Users</td>
<td>lists conneced users</td>
</tr>
<tr>
<td>128</td>
<td>Last Action</td>
<td>searches active session history for last command from non-oracle users. Needs diagnostic pack licence.</td>
</tr>
<tr>
<td>256</td>
<td>List Jobs</td>
<td>shows information about</td>
</tr>
<tr>
<td>512</td>
<td>Triggers</td>
<td>list triggers</td>
</tr>
<tr>
<td>1024</td>
<td>checkMK</td>
<td>checkMK output only</td>
</tr>
<tr>
<td>4096</td>
<td>Frequency Map</td>
<td>prints log frequency map of last 24 hours</td>
</tr>
</tbody>
</table><h2 id="progress-monitoring">Progress Monitoring</h2>
<blockquote>
<p>OraScn modes may take a very long time. Query action and module of the session after some seconds for a run time estimation.</p>
</blockquote>
<p>Use progress.sql to show current table and estimates.</p>
<h1 id="roadmap">Roadmap</h1>
<ul>
<li class="task-list-item"><input type="checkbox" class="task-list-item-checkbox" disabled=""> HTML output</li>
<li class="task-list-item"><input type="checkbox" class="task-list-item-checkbox" disabled=""> More pretty text output</li>
<li class="task-list-item"><input type="checkbox" class="task-list-item-checkbox" checked="true" disabled=""> Sql to monitor progress</li>
<li class="task-list-item"><input type="checkbox" class="task-list-item-checkbox" checked="true" disabled=""> CheckMK Output</li>
<li class="task-list-item"><input type="checkbox" class="task-list-item-checkbox" checked="true" disabled=""> Multiple Schema support (using wildcard, default %)</li>
<li class="task-list-item"><input type="checkbox" class="task-list-item-checkbox" checked="true" disabled=""> extended time information via v$archived_log</li>
<li class="task-list-item"><input type="checkbox" class="task-list-item-checkbox" checked="true" disabled=""> monitor progress, run estimates</li>
<li class="task-list-item"><input type="checkbox" class="task-list-item-checkbox" checked="true" disabled=""> inform last timestamp possible</li>
<li class="task-list-item"><input type="checkbox" class="task-list-item-checkbox" checked="true" disabled=""> log frequency map report</li>
<li class="task-list-item"><input type="checkbox" class="task-list-item-checkbox" checked="true" disabled=""> final report</li>
</ul>
<h2 id="license">License</h2>
<p>Distributed under the MIT License. See  <code>LICENSE.txt</code>  for more information.</p>
<h2 id="contact">Contact</h2>
<p>Author:  Robert Baric, ITGAIN Consulting Gesellschaft fuer IT-Beratung mbH, 2022  <a href="mailto:schroedingersdb@itgain.de">schroedingersdb@itgain.de</a></p>
<p>Project Link:  <a href="https://github.com/ITGAIN/schroedingersdb">https://github.com/ITGAIN/schroedingersdb</a></p>
<h2 id="acknowledgments">Acknowledgments</h2>
<p>Thanks to:</p>
<ul>
<li>Gerret Bachmann</li>
<li>Carlos de Frutos</li>
</ul>
</div>
</body>

</html>
