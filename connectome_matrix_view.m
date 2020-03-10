C = load ('./connectome.csv');
imagesc(C);
set(gca, 'XTick', 1:84);
set(gca, 'YTick', 1:84);
title('Connectome', 'FontSize', 10);
caxis([0 0.1]);
colorbar;
