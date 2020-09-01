use crate::{
    collections::PoolId,
    engine::{CollisionMeshId, SurfaceId},
    gfx::NodeId,
};

#[derive(Copy, Clone, Eq, PartialEq, Hash, Debug, Default)]
pub struct GeometryId(pub u64);

impl PoolId for GeometryId {
    fn next(&self) -> GeometryId {
        GeometryId(self.0 + 1)
    }
}

/// World geometry. Things that don't *necessarily* move or "think".
/// Think floors, walls, and ceilings.
#[derive(Debug)]
pub enum Geometry {
    StaticMap(StaticMap),
    Todo,
}

impl Default for Geometry {
    #[inline]
    fn default() -> Geometry {
        Geometry::Todo
    }
}

#[derive(Debug)]
pub struct Sector {
    surfaces: Vec<SurfaceId>,
}

#[derive(Debug, Default)]
pub struct StaticMap {
    pub collision_mesh: Option<CollisionMeshId>,
    pub sectors: Vec<Sector>,
    pub render_node: NodeId,
}