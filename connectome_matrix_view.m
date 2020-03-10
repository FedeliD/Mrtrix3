% use this function to load the 'connectome.csv' file and quickly
% visualize the connectivity matrix (n.of streamlines connecting
% the brain regions, scaled per volume and zero-diagonal)
C = load ('./connectome.csv');
imagesc(C);
set(gca, 'XTick', 1:84);
set(gca, 'YTick', 1:84);
title('Connectome', 'FontSize', 10);
caxis([0 0.1]);
colorbar;
