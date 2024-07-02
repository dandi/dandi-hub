from merge_config import merge_dicts


def test_add_top_level():
    d1 = {"k1": "v1"}
    d2 = {"k2": "v2"}
    combined = merge_dicts(d1, d2)
    assert "k1" in combined
    assert "k2" in combined
    assert combined["k1"] == "v1"
    assert combined["k2"] == "v2"


def test_update_top_level():
    d1 = {"k1": "v1"}
    d2 = {"k1": "v2"}
    combined = merge_dicts(d1, d2)
    assert "k1" in combined
    assert set(combined.keys()) == {"k1"}
    assert combined["k1"] == "v2"


def test_update_nested_value():
    inner = {"inner1": "v1", "inner2": "other"}
    d1 = {"k1": inner}
    d2 = {"k1": {"inner1": "v2"}}
    combined = merge_dicts(d1, d2)
    assert combined["k1"]["inner1"] == "v2"


def test_clobber_list():
    inner = ["inner1", "inner2"]
    d1 = {"k1": inner}
    d2 = {"k1": ["inner3"]}
    combined = merge_dicts(d1, d2)
    assert combined["k1"] == ["inner3"]


def test_clobber_nested_list():
    inner = ["v1", "v2"]
    d1 = {"k1": {"inner": inner}}
    d2 = {"k1": {"inner": ["v3"]}}
    combined = merge_dicts(d1, d2)
    assert combined["k1"]["inner"] == ["v3"]
