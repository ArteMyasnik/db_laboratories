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
    description TEXT,
    location_id INTEGER      NOT NULL REFERENCES locations (id) ON DELETE CASCADE,
    object_id   INTEGER REFERENCES objects (id) ON DELETE CASCADE
);

-- Таблица classifications (Классификации)
CREATE TABLE classifications
(
    id          SERIAL PRIMARY KEY,
    name        VARCHAR(255) NOT NULL UNIQUE,
    description TEXT
);

CREATE TABLE character_classification
(
    id                SERIAL PRIMARY KEY,
    character_id      INTEGER NOT NULL REFERENCES characters (id) ON DELETE CASCADE,
    classification_id INTEGER NOT NULL REFERENCES classifications (id) ON DELETE CASCADE,
    UNIQUE (character_id, classification_id)
);

-- Таблица character_event (Эмоции персонажей)
CREATE TABLE character_event
(
    id           SERIAL PRIMARY KEY,
    intensity    SMALLINT NOT NULL CHECK (intensity >= 1 AND intensity <= 10),
    character_id INTEGER  NOT NULL REFERENCES characters (id) ON DELETE CASCADE,
    emotion_id   INTEGER  NOT NULL REFERENCES emotions (id) ON DELETE CASCADE,
    event_id     INTEGER  NOT NULL REFERENCES events (id) ON DELETE CASCADE,
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

-- Заполнение таблицы classifications (Классификации)
INSERT INTO classifications (name, description)
VALUES ('воин', 'обладатель оружия'),
       ('колдун', 'обладатель магического предмета'),
       ('механик', 'обладатель технологического предмета'),
       ('хранитель', 'обладатель артефакта');

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
       (2, 1, 2, 2);
-- Хедрон, Радость, событие "Исследование Диаспара", интенсивность 2


-- Запрос, который считает сумму квадратов intensity, там где произведение трех id не превышает сам intensity
-- SELECT SUM(intensity * intensity) AS "Сумма квадратов intensity"
-- FROM character_event
-- WHERE (character_id * emotion_id * event_id) <= intensity;

/*
Функция автоматически управляет классификациями персонажа на основе его предметов:
1. При добавлении/изменении/удалении предмета проверяет типы имеющихся предметов
2. Добавляет классификации: 'хранитель' (артефакты), 'механик' (технологии), 'воин' (оружие), 'колдун' (магия)
3. Удаляет классификации, если у персонажа больше нет соответствующих предметов
4. Работает для операций INSERT/UPDATE/DELETE в таблице objects
*/
CREATE OR REPLACE FUNCTION assign_character_classifications()
    RETURNS TRIGGER AS
$$
DECLARE
    char_id INTEGER;
BEGIN
    -- Определяем id персонажа, которого это касается
    IF TG_OP = 'DELETE' THEN
        char_id := OLD.character_id;
    ELSE
        char_id := NEW.character_id;
    END IF;

    -- Для UPDATE проверяем, изменились ли важные поля
    IF TG_OP = 'UPDATE' THEN
        IF OLD.character_id IS NOT DISTINCT FROM NEW.character_id
            AND OLD.type = NEW.type THEN
            RETURN NEW;
        END IF;
    END IF;

    -- Обрабатываем изменения только если персонаж существует
    IF char_id IS NOT NULL THEN
        -- Выполняем операции удаления
        WITH
            -- Получаем id всех нужных классификаций
            class_ids AS (SELECT id, name
                          FROM classifications
                          WHERE name IN ('хранитель', 'механик', 'воин', 'колдун')),
            -- Проверяем наличие предметов каждого типа
            inventory_check
                AS (SELECT EXISTS(SELECT 1 FROM objects WHERE character_id = char_id AND type = 'артефакт')   AS has_artifacts,
                           EXISTS(SELECT 1 FROM objects WHERE character_id = char_id AND type = 'технология')   AS has_technologies,
                           EXISTS(SELECT 1 FROM objects WHERE character_id = char_id AND type = 'оружие')     AS has_weapons,
                           EXISTS(SELECT 1 FROM objects WHERE character_id = char_id AND type = 'магия')      AS has_magic),
            -- Формируем список классификаций для удаления
            to_delete AS (SELECT char_id AS character_id, c.id AS classification_id
                          FROM class_ids c, inventory_check i
                          WHERE (c.name = 'хранитель' AND NOT i.has_artifacts)
                             OR (c.name = 'механик' AND NOT i.has_technologies)
                             OR (c.name = 'воин' AND NOT i.has_weapons)
                             OR (c.name = 'колдун' AND NOT i.has_magic))
        DELETE
        FROM character_classification
            USING to_delete d
        WHERE character_classification.character_id = d.character_id
          AND character_classification.classification_id = d.classification_id;

        -- Выполняем операции вставки
        WITH
            -- Получаем id всех нужных классификаций
            class_ids AS (SELECT id, name
                          FROM classifications
                          WHERE name IN ('хранитель', 'механик', 'воин', 'колдун')),
            -- Проверяем наличие предметов каждого типа
            inventory_check
                AS (SELECT EXISTS(SELECT 1 FROM objects WHERE character_id = char_id AND type = 'артефакт')   AS has_artifacts,
                           EXISTS(SELECT 1 FROM objects WHERE character_id = char_id AND type = 'технология')   AS has_technologies,
                           EXISTS(SELECT 1 FROM objects WHERE character_id = char_id AND type = 'оружие')     AS has_weapons,
                           EXISTS(SELECT 1 FROM objects WHERE character_id = char_id AND type = 'магия')      AS has_magic),
             -- Формируем список классификаций для добавления
                to_insert AS (SELECT char_id AS character_id, c.id AS classification_id
                           FROM class_ids c, inventory_check i
                           WHERE (c.name = 'хранитель' AND i.has_artifacts)
                              OR (c.name = 'механик' AND i.has_technologies)
                              OR (c.name = 'воин' AND i.has_weapons)
                              OR (c.name = 'колдун' AND i.has_magic))
        INSERT
        INTO character_classification (character_id, classification_id)
        SELECT i.character_id, i.classification_id
        FROM to_insert i
        ON CONFLICT (character_id, classification_id) DO NOTHING;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


-- Триггер
CREATE TRIGGER trigger_assign_character_classifications
    AFTER INSERT OR UPDATE OR DELETE
    ON objects
    FOR EACH ROW
EXECUTE FUNCTION assign_character_classifications();


-- /*
-- Функция автоматически управляет классификациями персонажа на основе его предметов:
-- 1. При добавлении/изменении/удалении предмета проверяет типы имеющихся предметов
-- 2. Добавляет классификации: 'хранитель' (артефакты), 'механик' (технологии), 'воин' (оружие), 'колдун' (магия)
-- 3. Удаляет классификации, если у персонажа больше нет соответствующих предметов
-- 4. Работает для операций INSERT/UPDATE/DELETE в таблице objects
-- */
-- CREATE OR REPLACE FUNCTION assign_character_classifications()
--     RETURNS TRIGGER AS
-- $$
-- DECLARE
--     char_id INTEGER;
-- BEGIN
--     -- Определяем id персонажа, которого это касается
--     IF TG_OP = 'DELETE' THEN
--         char_id := OLD.character_id;
--     ELSE
--         char_id := NEW.character_id;
--     END IF;
--
--     -- Для UPDATE проверяем, изменились ли важные поля
--     IF TG_OP = 'UPDATE' THEN
--         IF OLD.character_id IS NOT DISTINCT FROM NEW.character_id
--             AND OLD.type = NEW.type THEN
--             RETURN NEW;
--         END IF;
--     END IF;
--
--     -- Обрабатываем изменения только если персонаж существует
--     IF char_id IS NOT NULL THEN
--         WITH
--             -- Получаем id всех нужных классификаций
--             class_ids AS (
--                 SELECT id, name
--                 FROM classifications
--                 WHERE name IN ('хранитель', 'механик', 'воин', 'колдун')
--             ),
--             -- Проверяем наличие предметов каждого типа
--             inventory_check AS (
--                 SELECT
--                     EXISTS(SELECT 1 FROM objects WHERE character_id = char_id AND type = 'артефакт') AS has_artifacts,
--                     EXISTS(SELECT 1 FROM objects WHERE character_id = char_id AND type = 'технология') AS has_technologies,
--                     EXISTS(SELECT 1 FROM objects WHERE character_id = char_id AND type = 'оружие') AS has_weapons,
--                     EXISTS(SELECT 1 FROM objects WHERE character_id = char_id AND type = 'магия') AS has_magic
--             ),
--             -- Формируем список классификаций для удаления
--             to_delete AS (
--                 SELECT char_id AS character_id, c.id AS classification_id
--                 FROM class_ids c, inventory_check i
--                 WHERE (c.name = 'хранитель' AND NOT i.has_artifacts)
--                    OR (c.name = 'механик' AND NOT i.has_technologies)
--                    OR (c.name = 'воин' AND NOT i.has_weapons)
--                    OR (c.name = 'колдун' AND NOT i.has_magic)
--             ),
--             -- Формируем список классификаций для добавления
--             to_insert AS (
--                 SELECT char_id AS character_id, c.id AS classification_id
--                 FROM class_ids c, inventory_check i
--                 WHERE (c.name = 'хранитель' AND i.has_artifacts)
--                    OR (c.name = 'механик' AND i.has_technologies)
--                    OR (c.name = 'воин' AND i.has_weapons)
--                    OR (c.name = 'колдун' AND i.has_magic)
--             )
--         -- Выполняем операции удаления и вставки
--         DELETE FROM character_classification
--         USING to_delete d
--         WHERE character_classification.character_id = d.character_id
--           AND character_classification.classification_id = d.classification_id;
--
--         INSERT INTO character_classification (character_id, classification_id)
--         SELECT i.character_id, i.classification_id
--         FROM to_insert i
--         ON CONFLICT (character_id, classification_id) DO NOTHING;
--     END IF;
--
--     RETURN NEW;
-- END;
-- $$ LANGUAGE plpgsql;
--
-- -- Триггер
-- CREATE TRIGGER trigger_assign_character_classifications
--     AFTER INSERT OR UPDATE OR DELETE
--     ON objects
--     FOR EACH ROW
-- EXECUTE FUNCTION assign_character_classifications();