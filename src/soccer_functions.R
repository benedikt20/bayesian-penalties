# Bayesian soccer penalties
#
# Helper functions and parameters
# ----------------------------------------------------------
# Benedikt Farag, benedikt.farag@yale.edu
# Yale University - Department of Statistics and Data Science
# December 15th 2025
# ----------------------------------------------------------



# ===========================================================
# Function to create a probability grid from a fitted model
# ===========================================================

make_prob_grid <- function(model_fit) {
  # make prediction grid
  goal_grid <- expand.grid(
    y_end = seq(lpost, rpost, length.out = Y_POINTS), 
    z_end = seq(0, bar, length.out = Z_POINTS) 
  )

  # compute the posterior predictions over the grid
  posterior <- fitted(
    model_fit, 
    newdata = goal_grid,
    re_formula = NA       # marginalize over random effects
  )

  # combine posterior with the grid
  prob_grid <- as.data.frame(posterior) %>%
    bind_cols(goal_grid)

  return(prob_grid)
}

# ===========================================================
# Function to compute risk-adjusted shot probabilities 
# and return plots
# ===========================================================

# make function to plot
plot_riskshot <- function(prob_grid, sigma_y, sigma_z, rho) {
  # covariance matrix for the bivariate normal
  cov_matrix <- matrix(c(sigma_y^2, rho*sigma_y*sigma_z, 
                       rho*sigma_y*sigma_z, sigma_z^2), 2, 2)

  # Integration parameters
  dy <- (rpost - lpost) / (Y_POINTS - 1)
  dz <- bar / (Z_POINTS - 1)
  dA <- dy * dz

  # ground shot: probability of scoring
  ground_line <- prob_grid %>% 
    filter(z_end == min(z_end)) %>%
    select(y_end, ground_prob = Estimate)

  get_ground_prob <- function(aim_y) {
    idx <- which.min(abs(ground_line$y_end - aim_y))
    return(ground_line$ground_prob[idx])
  }

  prob_grid$riskProb <- NA

  # loop over all aim points, we separate the integral to air and ground components
  for(i in 1:nrow(prob_grid)) {
    aim_y <- prob_grid$y_end[i]
    aim_z <- prob_grid$z_end[i]
    
    # air component (convolution over the air shots)
    densities <- dmvnorm(
      x = cbind(prob_grid$y_end, prob_grid$z_end), 
      mean = c(aim_y, aim_z), 
      sigma = cov_matrix
    )
    # Integration: Prob_Goal * Probability_of_Landing_Here * Area
    prob_air <- sum(prob_grid$Estimate * densities * dA)
    
    # ground shot component (pnorm on z, the probability of landing below 0)
    prob_below_zero <- pnorm(0, mean = aim_z, sd = sigma_z)
    
    # ground shots: estimated by the ground line probability
    prob_ground <- prob_below_zero * get_ground_prob(aim_y)
    
    # total risk-adjusted probability is the sum of both components
    prob_grid$riskProb[i] <- prob_air + prob_ground
  }

  p1 <- ggplot(prob_grid, aes(x = y_end, y = z_end)) +
    geom_raster(aes(fill = riskProb)) + 
    goalframe(title = "Posterior Probability P(Goal | Aim)", fill_name = "")

  p2 <- ggplot(prob_grid, aes(x = Estimate, y = riskProb)) +
    geom_point(alpha = 0.3, size=1) +
    geom_abline(slope = 1, intercept = 0, color = "red", linetype = "dashed") +
    labs(
      title = "Risk-Adjusted vs. Naive Goal Probabilities",
      x = "P(Goal | Location)", y = "P(Goal | Aim)") +
    theme_bw() # + xlim(0,1) #+ ylim(0,1)

  list(surface = p1, comparison = p2)
}

# ===========================================================
# Plot standard deviation coefficients in meters
# ===========================================================

plot_sdcoef_meters <- function(model, param_name, global_intercept, title_text) {
  
  # Get random effects for the specified parameter
  df <- ranef(model)$taker[, , param_name] %>%
    as.data.frame() %>%
    tibble::rownames_to_column("taker")
  
  # Convert to meter units: Sigma = exp( Global + Deviation )
  df_trans <- df %>%
    mutate(
      Sigma_Meters = exp(global_intercept + Estimate),
      # Transform the Confidence Intervals too
      Lower_CI     = exp(global_intercept + Q2.5),
      Upper_CI     = exp(global_intercept + Q97.5)
    ) %>%
    arrange(Sigma_Meters) # sort by Sigma in meters
  
  # get head and tail
  df_extremes <- bind_rows(head(df_trans, 10), tail(df_trans, 10))
  
  ggplot(df_extremes, aes(x = reorder(taker, Sigma_Meters), y = Sigma_Meters)) +
    geom_point(size = 2) +
    geom_errorbar(aes(ymin = Lower_CI, ymax = Upper_CI)) +
    geom_hline(yintercept = exp(global_intercept), linetype = "dashed", color = "red") +
    coord_flip() +
    labs(
      title = title_text, 
      y = "Standard deviation (m)", 
      x = ""
    ) +
    theme_bw()
}



# ===========================================================
# Goal frame setup for ggplot2
# ===========================================================

goalframe <- function(
  title     = NULL,
  fill_name = NULL,
  fill_limits   = c(0, 1)
) {
  list(
    # Goal frame
    geom_rect(
      xmin = lpost, xmax = rpost, ymin = 0, ymax = bar,
      fill = NA, color = "black", size = 0.3
    ),
    geom_rect(
      xmin = lpost - delta, xmax = rpost + delta,
      ymin = 0, ymax = bar + delta,
      fill = NA, color = "black", size = 0.3
    ),
    geom_segment(
      x = -4, y = 0, xend = 4, yend = 0,
      color = "black", size = 0.3
    ),

    scale_y_continuous(
      limits = c(0, bar + 2 * delta),
      breaks = seq(0, bar + 2 * delta, by = 0.5)
    ),
    scale_fill_gradientn(
      colours = c("blue", "cyan", "yellow", "red"),
      if (!is.null(fill_name)) name = fill_name,
      #name = fill_name,
      limits = fill_limits
    ),
    coord_fixed(ratio = 1),
    theme_test(),

    # Title (optional)
    if (!is.null(title)) labs(title = title, x = "y (m)", y = "z (m)")
  )
}

just_goalframe <- list(
  geom_rect(
    xmin = lpost, xmax = rpost, ymin = 0, ymax = bar,
    fill = NA, color = "black", size = 0.3
  ),
  geom_rect(
    xmin = lpost - delta, xmax = rpost + delta,
    ymin = 0, ymax = bar + delta,
    fill = NA, color = "black", size = 0.3
  ),
  geom_segment(
    x = -5, y = 0, xend = 5, yend = 0,
    color = "black", size = 0.3
  ),
  # scale_y_continuous(
  #   limits = c(0, bar + 2 * delta),
  #   breaks = seq(0, bar + 2 * delta, by = 0.5)
  # ),
  theme_test(),
  coord_fixed(ratio = 1),
  labs(x = "y (m)", y = "z (m)")
)
