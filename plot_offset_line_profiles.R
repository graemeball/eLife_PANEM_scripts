# Plot offset line profiles using R Studio
# Author: John Eykelenboom, 2025

# Load required package
library(ggplot2) # ggplot2 is used for creating the plot

# Read the data file
df <- read.csv("your_file.csv") # Change to your actual filename

# Filter the data to include only the desired range of Distance and Time
df_filtered <- df[
df$Distance >= 4.5 & df$Distance <= 12.5 & # Keep only Distance values between 4.5 and 12.5
df$Time >= 4 & df$Time <= 14, # Keep only Time values between 4 and 14
]

# Create the plot using ggplot
ggplot(df_filtered, aes(
x = Distance, # X-axis: Distance (filtered)
y = Intensity + Time * 0.1, # Y-axis: Intensity offset by Time * 0.1
color = factor(Time) # Color: Different color for each Time value
)) +
geom_line() + # Draws lines for each Time value
scale_color_viridis_d() + # Uses Viridis color scale for better visibility
theme_minimal() + # Uses a clean, minimal theme for better readability
labs(
title = "Intensity vs Distance Over Time (Offset Applied)", # Main plot title
x = "Distance", # X-axis label
y = "Intensity (Offset by Time)", # Y-axis label (shows offset effect)
color = "Time" # Legend label for colors
)

# Save the plot as a high-quality PDF
#  "my_plot.pdf" → Output filename (change as needed)
#  width = 8, height = 6 → Plot dimensions in inches
#  dpi = 300 → High resolution for publication-quality output
ggsave("my_plot.pdf", width = 8, height = 6, dpi = 300)

