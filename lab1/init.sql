-- Таблица emotions (Эмоции)
CREATE TABLE emotions
(
    id   SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL UNIQUE
);

-- Таблица characters (Персонажи)
CREATE TABLE characters
(
    id   SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL UNIQUE
);

-- Таблица roles (Роли)
CREATE TABLE roles
(
    id           SERIAL PRIMARY KEY,
    role         VARCHAR(255) UNIQUE DEFAULT 'None' NOT NULL,
    character_id INTEGER UNIQUE                     NOT NULL REFERENCES characters (id) ON DELETE CASCADE,
    significance SMALLINT                           NOT NULL CHECK (significance BETWEEN 1 AND 9)
);

-- Таблица locations (Локации)
CREATE TABLE locations
(
    id   SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL UNIQUE
);

-- Таблица objects (Объекты)
CREATE TABLE objects
(
    id                SERIAL PRIMARY KEY,
    name              VARCHAR(255) NOT NULL UNIQUE,
    type              VARCHAR(255) NOT NULL DEFAULT 'объект' CHECK (type IN
                                                                    ('объект', 'артефакт', 'технология', 'ресурс',
                                                                     'декорация', 'оружие', 'магия')),
    description       TEXT,
    character_id      INTEGER      REFERENCES characters (id) ON DELETE SET NULL,
    found_location_id INTEGER      NOT NULL REFERENCES locations (id) ON DELETE CASCADE
);

-- Таблица events (События)
CREATE TABLE events
(
    id          SERIAL PRIMARY KEY,
    name        VARCHAR(255) NOT NULL UNIQUE,
    location_id INTEGER      NOT NULL REFERENCES locations (id) ON DELETE CASCADE,
    object_id   INTEGER REFERENCES objects (id) ON DELETE CASCADE,
    description TEXT
);

-- Таблица character_event (Эмоции персонажей)
CREATE TABLE character_event
(
    id           SERIAL PRIMARY KEY,
    character_id INTEGER  NOT NULL REFERENCES characters (id) ON DELETE CASCADE,
    emotion_id   INTEGER  NOT NULL REFERENCES emotions (id) ON DELETE CASCADE,
    event_id     INTEGER  NOT NULL REFERENCES events (id) ON DELETE CASCADE,
    intensity    SMALLINT NOT NULL CHECK (intensity >= 1 AND intensity <= 10),
    UNIQUE (character_id, emotion_id, event_id)
);

-- Заполнение таблицы emotions (Эмоции)
INSERT INTO emotions (name)
VALUES ('Радость'),
       ('Упоение'),
       ('Ошеломление'),
       ('Одиночество');

-- Заполнение таблицы characters (Персонажи)
INSERT INTO characters (name)
VALUES ('Олвин'),
       ('Хедрон');

-- Заполнение таблицы roles (Роли персонажей)
INSERT INTO roles (role, significance, character_id)
VALUES ('Главный герой', 9, 1),
       ('Шут', 6, 2);

-- Заполнение таблицы locations (Локации)
INSERT INTO locations (name)
VALUES ('Диаспар'),
       ('Пустыня'),
       ('Башня Лоранна');

-- Заполнение таблицы objects (Объекты)
INSERT INTO objects (name, type, description, found_location_id)
VALUES ('Экран монитора', 'технология', 'Устройство для отображения изображений', 1),
       ('Решетка', 'объект', 'Преграда на границе Диаспара', 1),
       ('Ручка управления', 'технология', 'Инструмент для управления экраном', 1);

-- Заполнение таблицы events (События)
INSERT INTO events (name, location_id, description)
VALUES ('Победа Олвина', 1, 'Олвин достигает своей цели'),
       ('Исследование Диаспара', 1, 'Олвин исследует город снаружи');

-- Заполнение таблицы character_event (Эмоции персонажей)
INSERT INTO character_event (character_id, emotion_id, event_id, intensity)
VALUES (1, 1, 1, 9), -- Олвин, Радость, событие "Победа Олвина", интенсивность 9
       (1, 2, 1, 8), -- Олвин, Упоение, событие "Победа Олвина", интенсивность 8
       (2, 4, 1, 4), -- Хедрон, Одиночество, событие "Победа Олвина", интенсивность 4
       (1, 3, 2, 7), -- Олвин, Ошеломление, событие "Исследование Диаспара", интенсивность 7
       (1, 4, 2, 6), -- Олвин, Одиночество, событие "Исследование Диаспара", интенсивность 6
       (2, 1, 2, 2); -- Хедрон, Радость, событие "Исследование Диаспара", интенсивность 2


-- Запрос, который считает сумму квадратов intensity, там где произведение трех id не превышает сам intensity
-- SELECT SUM(intensity * intensity) AS "Сумма квадратов intensity"
-- FROM character_event
-- WHERE (character_id * emotion_id * event_id) <= intensity;