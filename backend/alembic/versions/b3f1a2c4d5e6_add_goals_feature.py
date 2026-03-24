"""add goals feature

Revision ID: b3f1a2c4d5e6
Revises: 0c9db949a971
Create Date: 2026-03-24 10:00:00.000000

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa


revision: str = 'b3f1a2c4d5e6'
down_revision: Union[str, Sequence[str], None] = '0c9db949a971'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # ── 1. Create goals table ──────────────────────────────────────
    op.create_table(
        'goals',
        sa.Column('id',                      sa.Integer(),      nullable=False),
        sa.Column('user_id',                 sa.Integer(),      nullable=False),
        sa.Column('title',                   sa.String(255),    nullable=False),
        sa.Column('target_role',             sa.String(255),    nullable=False),
        sa.Column('target_company',          sa.String(255),    nullable=True),
        sa.Column('deadline',                sa.DateTime(),     nullable=True),
        sa.Column('status',                  sa.String(50),     nullable=True),
        sa.Column('weekly_interview_target', sa.Integer(),      nullable=True),
        sa.Column('current_week_count',      sa.Integer(),      nullable=True),
        sa.Column('current_week_start',      sa.DateTime(),     nullable=True),
        sa.Column('roadmap_id',              sa.Integer(),      nullable=True),
        sa.Column('resume_id',               sa.Integer(),      nullable=True),
        sa.Column('coach_tip',               sa.Text(),         nullable=True),
        sa.Column('coach_tip_updated_at',    sa.DateTime(),     nullable=True),
        sa.Column('created_at',              sa.DateTime(),     nullable=True),
        sa.Column('updated_at',              sa.DateTime(),     nullable=True),
        sa.Column('achieved_at',             sa.DateTime(),     nullable=True),
        sa.ForeignKeyConstraint(['user_id'],    ['users.id'],    ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['roadmap_id'], ['roadmaps.id'], ondelete='SET NULL'),
        sa.ForeignKeyConstraint(['resume_id'],  ['resumes.id'],  ondelete='SET NULL'),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index(op.f('ix_goals_id'),      'goals', ['id'],      unique=False)
    op.create_index(op.f('ix_goals_user_id'), 'goals', ['user_id'], unique=False)

    # ── 2. Add goal_id to interviews ───────────────────────────────
    op.add_column('interviews',
        sa.Column('goal_id', sa.Integer(), nullable=True)
    )
    op.create_foreign_key(
        'fk_interviews_goal_id',
        'interviews', 'goals',
        ['goal_id'], ['id'],
        ondelete='SET NULL',
    )

    # ── 3. Add goal_id to roadmaps ─────────────────────────────────
    op.add_column('roadmaps',
        sa.Column('goal_id', sa.Integer(), nullable=True)
    )
    op.create_foreign_key(
        'fk_roadmaps_goal_id',
        'roadmaps', 'goals',
        ['goal_id'], ['id'],
        ondelete='SET NULL',
    )


def downgrade() -> None:
    op.drop_constraint('fk_roadmaps_goal_id',   'roadmaps',   type_='foreignkey')
    op.drop_column('roadmaps', 'goal_id')

    op.drop_constraint('fk_interviews_goal_id', 'interviews', type_='foreignkey')
    op.drop_column('interviews', 'goal_id')

    op.drop_index(op.f('ix_goals_user_id'), table_name='goals')
    op.drop_index(op.f('ix_goals_id'),      table_name='goals')
    op.drop_table('goals')