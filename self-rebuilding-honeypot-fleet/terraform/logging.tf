# Dashboard: Logs Insights queries over Cowrie JSON events
resource "aws_cloudwatch_dashboard" "honeypot" {
  dashboard_name = "honeypot-fleet"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "log"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "Top attacker IPs"
          region = var.region
          view   = "table"
          query  = "SOURCE '${aws_cloudwatch_log_group.honeypot.name}' | filter eventid = 'cowrie.login.failed' | stats count(*) as attempts by src_ip | sort attempts desc | limit 10"
        }
      },
      {
        type   = "log"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "Top usernames tried"
          region = var.region
          view   = "table"
          query  = "SOURCE '${aws_cloudwatch_log_group.honeypot.name}' | filter eventid = 'cowrie.login.failed' | stats count(*) as attempts by username | sort attempts desc | limit 10"
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 6
        width  = 24
        height = 6
        properties = {
          title  = "Commands run after login"
          region = var.region
          view   = "table"
          query  = "SOURCE '${aws_cloudwatch_log_group.honeypot.name}' | filter eventid = 'cowrie.command.input' | fields @timestamp, src_ip, input | sort @timestamp desc | limit 20"
        }
      }
    ]
  })
}
