-- 1. Таблица СТАНЦИЯ
CREATE TABLE станция (
    код_станции VARCHAR(10) PRIMARY KEY,
    название VARCHAR(50) NOT NULL,
    длина_платформы INTEGER NOT NULL CHECK (длина_платформы >= 50 AND длина_платформы <= 1500),
    регион VARCHAR(30),
    тип_электрификации VARCHAR(20) CHECK (тип_электрификации IN ('Постоянный_ток', 'Переменный_ток', 'Не_электрифицирована'))
);

-- 2. Таблица МАРШРУТ
CREATE TABLE маршрут (
    код_маршрута VARCHAR(15) PRIMARY KEY,
    станция_начала VARCHAR(10) NOT NULL REFERENCES станция(код_станции),
    станция_конца VARCHAR(10) NOT NULL REFERENCES станция(код_станции),
    расчётное_время_пути TIME NOT NULL,
    допустимые_классы_вагонов TEXT,
    статус VARCHAR(10) NOT NULL DEFAULT 'Черновик' CHECK (статус IN ('Черновик', 'Активен', 'Архив'))
);

-- 3. Таблица ОСТАНОВКА_НА_МАРШРУТЕ
CREATE TABLE остановка_на_маршруте (
    код_маршрута VARCHAR(15) NOT NULL REFERENCES маршрут(код_маршрута),
    код_станции VARCHAR(10) NOT NULL REFERENCES станция(код_станции),
    порядковый_номер INTEGER NOT NULL CHECK (порядковый_номер > 0),
    время_прибытия TIME NOT NULL,
    -- На конечной станции время отправления может отсутствовать.
    время_отправления TIME CHECK (время_отправления >= время_прибытия),
    длительность_стоянки INTEGER GENERATED ALWAYS AS (EXTRACT(EPOCH FROM (время_отправления - время_прибытия))/60) STORED,
    PRIMARY KEY (код_маршрута, код_станции)
);

-- 4. Таблица РЕЙС
CREATE TABLE рейс (
    номер_рейса VARCHAR(20) NOT NULL,
    дата_отправления DATE NOT NULL,
    код_маршрута VARCHAR(15) NOT NULL REFERENCES маршрут(код_маршрута),
    время_отправления TIME NOT NULL,
    пункт_назначения VARCHAR(50) NOT NULL,
    доступные_места INTEGER CHECK (доступные_места >= 0),
    статус_продажи VARCHAR(15) NOT NULL CHECK (статус_продажи IN ('Открыта', 'Закрыта', 'Пригород')),
    плановая_дата DATE,
    реальная_дата DATE,
    реальное_время TIME,
    причина_задержки VARCHAR(100),
    PRIMARY KEY (номер_рейса, дата_отправления),
    CONSTRAINT check_reality_dates CHECK (
        (реальная_дата IS NULL AND реальное_время IS NULL) OR 
        (реальная_дата IS NOT NULL AND реальное_время IS NOT NULL)
    )
);

-- 5. Таблица ПАССАЖИР
CREATE TABLE пассажир (
    серия_и_номер_паспорта VARCHAR(12) PRIMARY KEY,
    фио VARCHAR(100) NOT NULL,
    телефон VARCHAR(20),
    email VARCHAR(50),
    дата_рождения DATE CHECK (дата_рождения <= (CURRENT_DATE - INTERVAL '14 years'))
);

-- 6. Таблица ВАГОН
CREATE TABLE вагон (
    номер_вагона VARCHAR(10) PRIMARY KEY,
    тип_вагона VARCHAR(20) NOT NULL CHECK (тип_вагона IN ('Купе', 'Плацкарт', 'СВ', 'Общий')),
    класс_обслуживания VARCHAR(10) NOT NULL CHECK (класс_обслуживания IN ('Эконом', 'Стандарт', 'Бизнес')),
    тип_тележки VARCHAR(10) NOT NULL CHECK (тип_тележки IN ('Type1', 'Type2')),
    вместимость INTEGER NOT NULL CHECK (вместимость >= 20 AND вместимость <= 100),
    статус_то VARCHAR(15) NOT NULL DEFAULT 'Готов' CHECK (статус_то IN ('Готов', 'В ремонте', 'Списан'))
);

-- 7. Таблица ЛОКОМОТИВ
CREATE TABLE локомотив (
    id_локомотива SERIAL PRIMARY KEY,
    тип_тяги VARCHAR(20) NOT NULL CHECK (тип_тяги IN ('Электровоз', 'Тепловоз', 'Дизель')),
    мощность_квт INTEGER NOT NULL CHECK (мощность_квт >= 1000),
    дата_последнего_то DATE NOT NULL,
    ресурс_пробега_км INTEGER NOT NULL CHECK (ресурс_пробега_км >= 0)
);

-- 8. Таблица СОСТАВ_ПОЕЗДА
CREATE TABLE состав_поезда (
    id_состава SERIAL PRIMARY KEY,
    номер_рейса VARCHAR(20) NOT NULL,
    дата_отправления DATE NOT NULL,
    схема_сцепки TEXT,
    статус_формирования VARCHAR(15) NOT NULL DEFAULT 'Черновик' CHECK (статус_формирования IN ('Черновик', 'Утверждён', 'В работе')),
    время_генерации_отчёта TIMESTAMP,
    FOREIGN KEY (номер_рейса, дата_отправления) REFERENCES рейс(номер_рейса, дата_отправления)
);

-- 9. Таблица ВАГОН_В_СОСТАВЕ
CREATE TABLE вагон_в_составе (
    id_состава INTEGER NOT NULL REFERENCES состав_поезда(id_состава),
    номер_вагона VARCHAR(10) NOT NULL REFERENCES вагон(номер_вагона),
    порядковый_номер_в_составе INTEGER NOT NULL CHECK (порядковый_номер_в_составе >= 1 AND порядковый_номер_в_составе <= 20),
    позиция_сцепки VARCHAR(10),
    совместимость_с_платформой BOOLEAN NOT NULL DEFAULT TRUE,
    PRIMARY KEY (id_состава, номер_вагона)
);

-- 10. Таблица НАЗНАЧЕНИЕ_ЛОКОМОТИВА
CREATE TABLE назначение_локомотива (
    id_назначения SERIAL PRIMARY KEY,
    номер_рейса VARCHAR(20) NOT NULL,
    дата_отправления DATE NOT NULL,
    id_локомотива INTEGER NOT NULL REFERENCES локомотив(id_локомотива),
    дата_назначения DATE NOT NULL DEFAULT CURRENT_DATE,
    FOREIGN KEY (номер_рейса, дата_отправления) REFERENCES рейс(номер_рейса, дата_отправления)
);

-- 11. Таблица БИЛЕТ
CREATE TABLE билет (
    номер_билета VARCHAR(36) PRIMARY KEY,
    паспорт_пассажира VARCHAR(12) NOT NULL REFERENCES пассажир(серия_и_номер_паспорта),
    номер_рейса VARCHAR(20) NOT NULL,
    дата_отправления_рейса DATE NOT NULL,
    номер_вагона INTEGER NOT NULL CHECK (номер_вагона >= 1 AND номер_вагона <= 20),
    номер_места INTEGER NOT NULL CHECK (номер_места >= 1 AND номер_места <= 100),
    цена NUMERIC(10,2) NOT NULL CHECK (цена >= 0),
    дата_покупки DATE NOT NULL DEFAULT CURRENT_DATE,
    статус_возврата VARCHAR(10) NOT NULL DEFAULT 'Активен' CHECK (статус_возврата IN ('Активен', 'Возвращён')),
    время_блокировки_места TIMESTAMP,
    FOREIGN KEY (номер_рейса, дата_отправления_рейса) REFERENCES рейс(номер_рейса, дата_отправления)
);

-- Одно место может иметь только один активный билет на рейс.
-- Возвращённые билеты сохраняются, но не мешают повторной продаже места.
CREATE UNIQUE INDEX unique_active_place
    ON билет (номер_рейса, дата_отправления_рейса, номер_вагона, номер_места)
    WHERE статус_возврата = 'Активен';
