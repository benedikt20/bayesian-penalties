save_figs <- TRUE  # set to TRUE to save figures

# make directories if they do not exist
if (save_figs & !dir.exists("figures")) {
  dir.create("figures")
}
if (!dir.exists("figures/sy_sz_study")) {
  dir.create("figures/sy_sz_study")
}
if (!dir.exists("figures/rho_study")) {
  dir.create("figures/rho_study")
}
if (!dir.exists("models")) {
  dir.create("models")
}

rpost <- 3.66     # left post x coordinate (m)
lpost <- -rpost   # right post x coordinate (m)
bar <- 2.44       # goal height (m)
delta = 0.12      # post thickness
Y_POINTS <- 150   # number of points along y axis
Z_POINTS <- 50   # number of points along z axis
myseed <- 2025