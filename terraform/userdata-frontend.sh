#!/bin/bash
yum update -y
yum install -y httpd
systemctl start httpd
systemctl enable httpd

cat <<EOF >/var/www/html/index.html
<html>
  <h1>Group 6 DR Dashboard</h1>
  <button onclick="trigger()">Simulate Failover</button>
  <script>
    function trigger() {
      fetch("http://BACKEND_PRIVATE_IP:5000/failover")
        .then(()=>alert("Failover Triggered"));
    }
  </script>
</html>
EOF
