## Terraform for scripts to bootstrap
locals {

  # Windows systems 
  templatefiles_win = [
    
    
  ]

  script_contents_win = [
    for t in local.templatefiles_win : templatefile(t.name, t.variables)
  ]

  script_output_generated_win = [
    for t in local.templatefiles_win : "${path.module}/output/windows/${replace(basename(t.name), ".tpl", "")}"
  ]

  # reference in the main user_data for each windows system
  script_files_win = [
    for tf in local.templatefiles_win :
    replace(basename(tf.name), ".tpl", "")
  ]
}

resource "local_file" "generated_scripts_win" {
  count = length(local.templatefiles_win)
  filename = local.script_output_generated_win[count.index]
  content  = local.script_contents_win[count.index]
}
