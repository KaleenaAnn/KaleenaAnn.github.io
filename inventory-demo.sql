-- Inventory analysis with fictional data. Run with SQLite 3.25+.
-- Example: sqlite3 :memory: < inventory-demo.sql
PRAGMA foreign_keys = ON;

CREATE TABLE suppliers (
    supplier_id INTEGER PRIMARY KEY,
    supplier_name TEXT NOT NULL UNIQUE
);

CREATE TABLE parts (
    part_id INTEGER PRIMARY KEY,
    part_name TEXT NOT NULL,
    supplier_id INTEGER NOT NULL REFERENCES suppliers(supplier_id),
    reorder_point INTEGER NOT NULL CHECK (reorder_point >= 0)
);

CREATE TABLE stock_movements (
    movement_id INTEGER PRIMARY KEY,
    part_id INTEGER NOT NULL REFERENCES parts(part_id),
    movement_date TEXT NOT NULL,
    quantity_change INTEGER NOT NULL CHECK (quantity_change <> 0)
);

CREATE INDEX stock_movements_part_date
    ON stock_movements (part_id, movement_date, movement_id);

INSERT INTO suppliers VALUES (1, 'Coastal Components'), (2, 'Atlas Supply');

INSERT INTO parts VALUES
    (101, 'Connector', 1, 10),
    (102, 'Mounting bracket', 1, 5),
    (103, 'Cable assembly', 2, 8),
    (104, 'Protective cap', 2, 4);

-- Receipts are positive. Issues are negative.
INSERT INTO stock_movements VALUES
    (1, 101, '2026-10-01', 20),
    (2, 101, '2026-10-03', -8),
    (3, 101, '2026-10-06', -5),
    (4, 102, '2026-10-02', 12),
    (5, 102, '2026-10-07', -4),
    (6, 103, '2026-10-01', 15),
    (7, 103, '2026-10-05', -7);

-- Keep parts without movements in the inventory report.
CREATE VIEW inventory_balances AS
SELECT p.part_id,
       p.part_name,
       s.supplier_name,
       p.reorder_point,
       COALESCE(SUM(m.quantity_change), 0) AS on_hand
FROM parts AS p
JOIN suppliers AS s ON s.supplier_id = p.supplier_id
LEFT JOIN stock_movements AS m ON m.part_id = p.part_id
GROUP BY p.part_id, p.part_name, s.supplier_name, p.reorder_point;

-- Query 1: Current stock by part.
SELECT part_id, part_name, supplier_name, on_hand, reorder_point
FROM inventory_balances
ORDER BY part_id;

-- Query 2: Parts at or below their reorder point.
WITH reorder_candidates AS (
    SELECT part_name, supplier_name, on_hand, reorder_point
    FROM inventory_balances
    WHERE on_hand <= reorder_point
)
SELECT part_name, supplier_name, on_hand, reorder_point,
       reorder_point - on_hand AS units_below_point
FROM reorder_candidates
ORDER BY units_below_point DESC, part_name;

-- Query 3: Stock movement history and running balance for part 101.
SELECT movement_date, quantity_change,
       SUM(quantity_change) OVER (
           PARTITION BY part_id
           ORDER BY movement_date, movement_id
           ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
       ) AS running_balance
FROM stock_movements
WHERE part_id = 101
ORDER BY movement_date, movement_id;
