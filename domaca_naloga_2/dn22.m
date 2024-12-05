% Pot do datotek 
path_dn2 = './vozlisca_temperature_dn2.txt'; % Pot do datoteke z vozlišči in temperaturami
path_celice = './celice_dn2.txt'; % Pot do datoteke z informacijami o celicah

% 1. Prebere datoteko z vozlišči in temperaturami
if ~isfile(path_dn2)
    error('Datoteka %s ne obstaja. Preverite pot.', path_dn2);
end

opts = detectImportOptions(path_dn2, 'NumHeaderLines', 4); % Preskoči prve 4 vrstice
opts.VariableNames = {'x', 'y', 'temperature'};
opts.Delimiter = ',';
vozlisca_data = readtable(path_dn2, opts);

% 2. Prebere datoteko z informacijami o celicah
if ~isfile(path_celice)
    error('Datoteka %s ne obstaja. Preverite pot.', path_celice);
end

opts_cells = detectImportOptions(path_celice, 'NumHeaderLines', 2); % Preskoči prve 2 vrstice
opts_cells.VariableNames = {'pt1', 'pt2', 'pt3', 'pt4'};
opts_cells.Delimiter = ',';
celice_data = readtable(path_celice, opts_cells);

% Preveri uspešnost branja
if isempty(vozlisca_data) || isempty(celice_data)
    error('Datoteki nista pravilno prebrani. Preverite format.');
end

% 3. Priprava podatkov
x = vozlisca_data.x;
y = vozlisca_data.y;
temperature = vozlisca_data.temperature;

% 4. ScatteredInterpolant metoda
tic;
F_scattered = scatteredInterpolant(x, y, temperature, 'linear', 'none');
T1 = F_scattered(0.403, 0.503);
time_scattered = toc;

% 5. GriddedInterpolant metoda
tic;
x_unique = unique(x); % Unikatne vrednosti x
y_unique = unique(y); % Unikatne vrednosti y
[X, Y] = meshgrid(x_unique, y_unique); % MESHGRID oblika
T_grid = reshape(temperature, length(y_unique), length(x_unique)); % Temperaturni podatki

% Preklop iz MESHGRID v NDGRID format
X = X'; % Transpozicija X
Y = Y'; % Transpozicija Y
T_grid = T_grid'; % Transpozicija temperature

% Ustvarjanje interpolacijske funkcije
F_gridded = griddedInterpolant(X, Y, T_grid, 'linear', 'none');
T2 = F_gridded(0.403, 0.503);
time_gridded = toc;

% 6. Ročna bilinearna interpolacija
tic;
T3 = manualBilinearInterpolation(x, y, temperature, 0.403, 0.503, celice_data);
time_manual = toc;

% 7. Poišči največjo temperaturo
[max_temp, idx_max] = max(temperature);
max_coord = [x(idx_max), y(idx_max)];

% 8. Izpiši rezultate
fprintf('ScatteredInterpolant: T = %.2f, čas = %.4f s\n', T1, time_scattered);
fprintf('GriddedInterpolant: T = %.2f, čas = %.4f s\n', T2, time_gridded);
fprintf('Bilinearna interpolacija: T = %.2f, čas = %.4f s\n', T3, time_manual);
fprintf('Največja temperatura: %.2f pri koordinatah (%.3f, %.3f)\n', max_temp, max_coord(1), max_coord(2));

% Funkcija za ročno bilinearno interpolacijo
function T = manualBilinearInterpolation(x, y, temperature, x_target, y_target, celice_data)
    % Celice vsebujejo indekse vozlišč
    num_cells = height(celice_data);
    T = NaN;
    for i = 1:num_cells
        % Pridobi indekse vozlišč trenutne celice
        cell_indices = table2array(celice_data(i, :));
        cell_x = x(cell_indices);
        cell_y = y(cell_indices);
        cell_temps = temperature(cell_indices);

        % Preveri, če je točka znotraj trenutne celice
        if x_target >= min(cell_x) && x_target <= max(cell_x) && ...
           y_target >= min(cell_y) && y_target <= max(cell_y)
            % Koordinate celice
            xmin = min(cell_x);
            xmax = max(cell_x);
            ymin = min(cell_y);
            ymax = max(cell_y);
            
            % T11, T21, T12, T22 (vozlišča definirana v obratni smeri urinega kazalca)
            T11 = cell_temps(1);
            T21 = cell_temps(2);
            T22 = cell_temps(3);
            T12 = cell_temps(4);

            % Bilinearna interpolacija
            K1 = (xmax - x_target) / (xmax - xmin) * T11 + (x_target - xmin) / (xmax - xmin) * T21;
            K2 = (xmax - x_target) / (xmax - xmin) * T12 + (x_target - xmin) / (xmax - xmin) * T22;
            T = (ymax - y_target) / (ymax - ymin) * K1 + (y_target - ymin) / (ymax - ymin) * K2;
            return;
        end
    end
end
