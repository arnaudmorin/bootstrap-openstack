# Devops observing important instance live migration flow
How to live migrate 240K instances in a public cloud ?

What do you think about live-migrating 240k instances to upgrade your compute node kernels and the end-user should not notice any change ?

Recently, we started upgrade of our OpenStack from Juno to Newton release. We needed to have a flawless live migration process.
From a single instance to a Ceph based instance with a configuration drive and multiple additional volumes attached, all cases had to work without issues.                                     
For that, many patches have been cherry-picked and back-ported down to a Frankenstein Nova Juno code.
We also wrote tools to industrialize the rolling upgrade on thousand of compute nodes across multiple regions along with checking migration status, bandwidth usage and other related metrics.

These slides are created using reveal.js https://github.com/hakimel/reveal.js/

